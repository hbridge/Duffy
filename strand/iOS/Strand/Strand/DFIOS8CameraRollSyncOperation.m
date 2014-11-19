//
//  DFIOS8CameraRollSyncOperation.m
//  Strand
//
//  Created by Derek Parham on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFIOS8CameraRollSyncOperation.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

#import "DFAssetCache.h"
#import "DFCameraRollPhotoAsset.h"
#import "DFNotificationSharedConstants.h"
#import "DFPHAsset.h"
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFUser.h"

@implementation DFIOS8CameraRollSyncOperation

- (NSDictionary *)findAssetChangesBetweenTimes:(NSDate *)startDate beforeEndDate:(NSDate *)endDate
{
  // setup dicts for enumeration
  self.foundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownNotFoundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownAndFoundURLsToDates = [[self mapKnownPhotoURLsToDates:self.knownPhotos] mutableCopy];
  
  self.allObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  self.unsavedObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  DDLogDebug(@"%@ finding PHAssetChanges with startDate:%@ endDate:%@", self.class, startDate, endDate);
  NSDate *timerStartDate = [NSDate date];
  
  //enumerate PHAssets
  NSUInteger __block assetCount = 0;
  
  // setup photo fetch options
  PHFetchOptions *photoFetchOptions = [PHFetchOptions new];
  photoFetchOptions.sortDescriptors = @[
                                   [NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                 ascending:NO],
                                   ];
  NSMutableArray *photoPredicates = [NSMutableArray new];
  [photoPredicates addObject:[NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage]];
  if (startDate && endDate) {
    [photoPredicates addObject:[NSPredicate predicateWithFormat:@"creationDate >= %@", startDate]];
    [photoPredicates addObject:[NSPredicate predicateWithFormat:@"creationDate <= %@", endDate]];
  }
  if (photoPredicates.count > 0) {
    photoFetchOptions.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                              subpredicates:photoPredicates];
  }
  
  if (self.isCancelled) {
    return self.allObjectIDsToChanges;
  }
  
  // enumerate all the photo asets, scanning for changes as we go
  [self enumerateAssetsUsingCollectionsWithAssetOptions:photoFetchOptions assetBlock:^(PHAsset *asset, BOOL savedFromSwap) {
    assetCount++;
    [[DFAssetCache sharedCache] setAsset:asset forIdentifier:asset.localIdentifier];
    [self scanPHAssetForChange:asset savedFromSwap:savedFromSwap];
  }];

  if (self.isCancelled) {
    return self.allObjectIDsToChanges;
  }
  
  // Only look for deletions if we were scanning the entire camera roll!
  // if you look for deletions but are only scanning a subset, it will delete everything else
  if (!startDate && !endDate) {
    NSDictionary *removeChanges = [self removePhotosNotFound:self.knownNotFoundURLs];
    [self.allObjectIDsToChanges addEntriesFromDictionary:removeChanges];
    [self.unsavedObjectIDsToChanges addEntriesFromDictionary:removeChanges];
  }
  
  if (self.isCancelled) {
    return self.allObjectIDsToChanges;
  }
  [self flushChanges];
  DDLogInfo(@"Scan complete.  Took %.02f Change summary for %@ assets: \n%@",
            [[NSDate date]
             timeIntervalSinceDate:timerStartDate],
            @(assetCount),
            [self changeTypesToCountsForChanges:self.allObjectIDsToChanges]);
  
  return self.allObjectIDsToChanges;
}

- (void)enumerateAssetsUsingCollectionsWithAssetOptions:(PHFetchOptions *)assetOptions
                                             assetBlock:(void(^)(PHAsset *asset, BOOL savedFromSwap))assetBlock
{
  // First we want to go through all Albums the user has, in particular 
  PHFetchOptions *userAlbumsOptions = [PHFetchOptions new];
  userAlbumsOptions.predicate = [NSPredicate predicateWithFormat:@"estimatedAssetCount > 0"];
  PHFetchResult *userAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:userAlbumsOptions];

  [userAlbums enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger idx, BOOL *stop) {
    if ([assetCollection.localizedTitle isEqualToString:DFPhotosSaveLocationName]) {
      PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:assetCollection options:assetOptions];
      for (PHAsset *asset in assets) {
        assetBlock(asset, YES);
      }
    }
  }];
 
  // Now we go through all the Moments.  Note, we might want to move this over to albums at some point, this still picks up dups
  PHFetchOptions *collectionOptions = [PHFetchOptions new];
  collectionOptions.sortDescriptors = @[
                                        [NSSortDescriptor sortDescriptorWithKey:@"endDate" ascending:NO],
                                        ];
  PHFetchResult *allMomentsList = [PHCollectionList
                                   fetchMomentListsWithSubtype:PHCollectionListSubtypeMomentListCluster
                                   options:collectionOptions];
  for (PHCollectionList *momentList in allMomentsList) {
    PHFetchResult *collections = [PHCollection fetchCollectionsInCollectionList:momentList
                                                                        options:collectionOptions];
    for (PHAssetCollection *assetCollection in collections) {
      PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:assetCollection options:assetOptions];
      for (PHAsset *asset in assets) {
        assetBlock(asset, NO);
      }
    }
  }
}

- (void)scanPHAssetForChange:(PHAsset *)asset savedFromSwap:(BOOL)savedFromSwap
{
  if (self.unsavedObjectIDsToChanges.count > NumChangesFlushThreshold) {
    if (self.isCancelled) {
      return;
    }
    [self flushChanges];
  }
  
  NSURL *assetURL = [DFPHAsset URLForPHAssetLocalIdentifier:asset.localIdentifier];
  [self.knownNotFoundURLs removeObject:assetURL];
  
  // We have this asset in our DB, see if it matches what we expect
  if (![self.knownPhotos.photoURLSet containsObject:assetURL] && ![self.foundURLs containsObject:assetURL]) {
    DFPHAsset *dfphAsset = [DFPHAsset createWithPHAsset:asset inContext:self.managedObjectContext];
    DFPhoto *newPhoto = [DFPhoto createWithAsset:dfphAsset
                                          userID:[[DFUser currentUser] userID]
                                   savedFromSwap:savedFromSwap
                                       inContext:self.managedObjectContext];

    
    // store information about the new photo to notify
    self.unsavedObjectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
    self.allObjectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
    // add to list of knownURLs so we don't duplicate add it
    // in either case, add mappings
    [self.foundURLs addObject:assetURL];
    self.knownAndFoundURLsToDates[assetURL] = asset.creationDate;
  }
}


- (void)migrateAssets
{
  // fetch all DFCameraRollPhotoAssets, if any
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  
  NSEntityDescription *entityDescription = [[self.managedObjectContext.persistentStoreCoordinator.managedObjectModel
                                             entitiesByName]
                                            objectForKey:NSStringFromClass([DFCameraRollPhotoAsset class])];
  request.entity = entityDescription;
  
  NSError *error;
  NSArray *result = [self.managedObjectContext executeFetchRequest:request error:&error];
  if (!result) {
    [NSException raise:@"Could not fetch ALAssets"
                format:@"Error: %@", [error localizedDescription]];
  }
  
  // migrate them to iOS8 PHAssets
  if (result.count > 0) {
    DDLogInfo(@"%@ alAssets found on iOS8, migrating...", self.class);
    // for each alAsset get the corresponding iOS8 PHAsset and reassign
    // can't do in bulk because we need to know the which alAsset maps to which PHAsset
    for (DFCameraRollPhotoAsset *cameraRollAsset in result) {
      // keep track of the photo that the camera roll asset was attached to
      DFPhoto *photo = cameraRollAsset.photo;
      
      // get the PHAsset and create it's DFPHAsset
      NSURL *assetURL = [NSURL URLWithString:cameraRollAsset.alAssetURLString];
      PHAsset *phAsset = [[PHAsset fetchAssetsWithALAssetURLs:@[assetURL] options:nil] firstObject];
      DFPHAsset *dfphAsset = [DFPHAsset createWithPHAsset:phAsset inContext:self.managedObjectContext];
      
      // delete the old asset and set the dfphoto's new asset
      photo.asset = dfphAsset;
      [self.managedObjectContext deleteObject:cameraRollAsset];
    }
    
    [self.managedObjectContext save:&error];
    if (error) {
      DDLogError(@"%@: failed to save context after ALAsset migration: %@)", self.class, error);
    }
  }
}

- (NSArray *)photosToRemove:(NSSet *)photoURLsNotFound
{
  NSMutableArray *phAssetIDs = [NSMutableArray new];
  for (NSURL *url in photoURLsNotFound) {
    [phAssetIDs addObject:[DFPHAsset localIdentifierFromURL:url]];
  }
  return [DFPhotoStore photosWithPHAssetIdentifiers:phAssetIDs context:self.managedObjectContext];
}



@end
