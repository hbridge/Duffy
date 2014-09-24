//
//  DFCameraRollSyncOperation.m
//  Duffy
//
//  Created by Henry Bridge on 5/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollSyncOperation.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "DFPhotoCollection.h"
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFNotificationSharedConstants.h"
#import "DFAnalytics.h"
#import "DFDataHasher.h"
#import "NSNotificationCenter+DFThreadingAddons.h"
#import "DFCameraRollPhotoAsset.h"
#import "ALAsset+DFExtensions.h"
#import "UIDevice+DFHelpers.h"
#import "DFPHAsset.h"
#import "DFAssetCache.h"

static int NumChangesFlushThreshold = 100;

@interface DFCameraRollSyncOperation()

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) DFPhotoCollection *knownPhotos;
@property (nonatomic) dispatch_semaphore_t enumerationCompleteSemaphore;
@property (nonatomic, retain) NSMutableSet *foundURLs;
@property (nonatomic, retain) NSMutableSet *knownNotFoundURLs;
@property (nonatomic, retain) NSMutableDictionary *knownAndFoundURLsToDates;
@property (nonatomic, retain) NSMutableDictionary *allObjectIDsToChanges;
@property (nonatomic, retain) NSMutableDictionary *unsavedObjectIDsToChanges;

@end

@implementation DFCameraRollSyncOperation


- (void)main
{
  @autoreleasepool {
    DDLogInfo(@"Camera roll sync beginning.");
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    if ([UIDevice majorVersionNumber] >= 8) {
      // for iOS 8 devices, check to see if we need to migrate old assets
      [self migrateALAssets];
    }
    
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    self.knownPhotos = [DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext];
    
    if ([UIDevice majorVersionNumber] >= 8) {
      [self findPHAssetChanges];
    } else {
      [self findALAssetChanges];
    }
    
    
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    // gather info about total changes then send notification that a scan completed
    //NSDictionary *changeTypesToCounts = [self changeTypesToCountsForChanges:changes];
    //NSUInteger numAdded = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeAdded] unsignedIntegerValue];
    //NSUInteger numDeleted = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeRemoved] unsignedIntegerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFCameraRollSyncCompleteNotificationName
       object:self];
    });
  }
}

- (void)cancelled
{
  DDLogInfo(@"DFCameraRollSyncOperationCancelled.  Stopping.");
}

- (void)migrateALAssets
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

- (NSDictionary *)mapKnownPhotoURLsToDates:(DFPhotoCollection *)knownPhotos
{
  NSMutableDictionary *mapping = [[NSMutableDictionary alloc] init];
  
  for (DFPhoto *photo in [knownPhotos photoSet]) {
    mapping[photo.asset.canonicalURL] =
    [photo utcCreationDate];
  }
  
  return mapping;
}

- (NSDictionary *)findALAssetChanges
{
  // setup lists of objects
  self.enumerationCompleteSemaphore = dispatch_semaphore_create(0);
  self.foundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownNotFoundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownAndFoundURLsToDates = [[self mapKnownPhotoURLsToDates:self.knownPhotos] mutableCopy];
  
  self.allObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  self.unsavedObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  DDLogDebug(@"%@ finding ALAssetChanges", self.class);
  NSDate *startDate = [NSDate date];
  // scan camera roll
  ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
  [library
   enumerateGroupsWithTypes: ALAssetsGroupSavedPhotos
   usingBlock:[self enumerateGroupsBlockSkippingGroupsNamed:nil]
   failureBlock:[self libraryAccessFailureBlock]];
  dispatch_semaphore_wait(self.enumerationCompleteSemaphore, DISPATCH_TIME_FOREVER);
  [self flushChanges];
  
  // scan other items
  [library
   enumerateGroupsWithTypes: ALAssetsGroupAlbum
   usingBlock:[self enumerateGroupsBlockSkippingGroupsNamed:@[@"Camera Roll"]]
   failureBlock:[self libraryAccessFailureBlock]];
  
   dispatch_semaphore_wait(self.enumerationCompleteSemaphore, DISPATCH_TIME_FOREVER);
  
  if (self.isCancelled) {
    return self.allObjectIDsToChanges;
  }
  
  NSDictionary *removeChanges = [self removePhotosNotFound:self.knownNotFoundURLs];
  [self.allObjectIDsToChanges addEntriesFromDictionary:removeChanges];
  [self.unsavedObjectIDsToChanges addEntriesFromDictionary:removeChanges];
  [self flushChanges];
  DDLogInfo(@"Scan complete.  Took %.02f Change summary for all groups: \n%@", [[NSDate date] timeIntervalSinceDate:startDate], [self changeTypesToCountsForChanges:self.allObjectIDsToChanges]);
  
  return self.allObjectIDsToChanges;
}

- (NSDictionary *)findPHAssetChanges
{
  // setup dicts for enumeration
  self.foundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownNotFoundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownAndFoundURLsToDates = [[self mapKnownPhotoURLsToDates:self.knownPhotos] mutableCopy];
  
  self.allObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  self.unsavedObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  DDLogDebug(@"%@ finding PHAssetChanges", self.class);
  NSDate *startDate = [NSDate date];
  
  //enumerate PHAssets
  NSUInteger assetCount = 0;
  PHFetchOptions *assetOptions = [PHFetchOptions new];
  assetOptions.sortDescriptors = @[
                                   [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO],
                                   ];
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
        if (self.isCancelled) return self.allObjectIDsToChanges;
        if (asset.mediaType != PHAssetMediaTypeImage) continue;
        assetCount++;
        [[DFAssetCache sharedCache] setAsset:asset forIdentifier:asset.localIdentifier];
        [self scanPHAssetForChange:asset];
      }
    }
  }
  
  // enumeration finished
  if (self.isCancelled) {
    return self.allObjectIDsToChanges;
  }
  
  NSDictionary *removeChanges = [self removePhotosNotFound:self.knownNotFoundURLs];
  [self.allObjectIDsToChanges addEntriesFromDictionary:removeChanges];
  [self.unsavedObjectIDsToChanges addEntriesFromDictionary:removeChanges];
  [self flushChanges];
  DDLogInfo(@"Scan complete.  Took %.02f Change summary for %@ assets: \n%@",
            [[NSDate date]
             timeIntervalSinceDate:startDate],
            @(assetCount),
            [self changeTypesToCountsForChanges:self.allObjectIDsToChanges]);
  
  return self.allObjectIDsToChanges;
}

- (void)scanPHAssetForChange:(PHAsset *)asset
{
  if (self.unsavedObjectIDsToChanges.count > NumChangesFlushThreshold) {
    [self flushChanges];
  }
  
  NSURL *assetURL = [DFPHAsset URLForPHAssetLocalIdentifier:asset.localIdentifier];
  [self.knownNotFoundURLs removeObject:assetURL];
  
  // We have this asset in our DB, see if it matches what we expect
  if (![self.knownPhotos.photoURLSet containsObject:assetURL]) {
    DFPHAsset *dfphAsset = [DFPHAsset createWithPHAsset:asset inContext:self.managedObjectContext];
    DFPhoto *newPhoto = [DFPhoto createWithAsset:dfphAsset
                                          userID:[[DFUser currentUser] userID]
                                       inContext:self.managedObjectContext];
    
    // store information about the new photo to notify
    self.unsavedObjectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
    // add to list of knownURLs so we don't duplicate add it
    // in either case, add mappings
    [self.foundURLs addObject:assetURL];
    self.knownAndFoundURLsToDates[assetURL] = asset.creationDate;
  }
}


- (void)findRemoteChanges
{
  // TODO download a list of what the server thinks it has
  
  // TODO compare server list to whether we have photos with those ids or not, whether hashes match etc
}

- (ALAssetsLibraryGroupsEnumerationResultsBlock)enumerateGroupsBlockSkippingGroupsNamed:(NSArray *)groupNamesToSkip
{
  return ^(ALAssetsGroup *group, BOOL *stop) {
    if (self.isCancelled) {
      *stop = YES;
      dispatch_semaphore_signal(self.enumerationCompleteSemaphore);
      return;
    }
    if(group != nil) {
      NSString *groupName = [group valueForProperty:ALAssetsGroupPropertyName];
      if ([groupNamesToSkip containsObject:groupName]) {
        return;
      }
      
      [group setAssetsFilter:[ALAssetsFilter allPhotos]]; // only want photos for now
      DDLogInfo(@"Enumerating %d assets in %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
      [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:[self photosEnumerationBlock]];
    } else {
      dispatch_semaphore_signal(self.enumerationCompleteSemaphore);
    }
  };
}

- (ALAssetsLibraryAccessFailureBlock)libraryAccessFailureBlock {
  return ^(NSError *error) {
    DDLogError(@"Failed to enumerate photo groups: %@", error.localizedDescription);
    dispatch_semaphore_signal(self.enumerationCompleteSemaphore);
  };
}

- (ALAssetsGroupEnumerationResultsBlock)photosEnumerationBlock
{
  NSMutableDictionary __block *groupObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  return ^(ALAsset *photoAsset, NSUInteger index, BOOL *stop) {
    if(photoAsset != NULL) {
      if (self.isCancelled) {
        *stop = YES;
        return;
      }
      if (self.unsavedObjectIDsToChanges.count > NumChangesFlushThreshold) {
        [groupObjectIDsToChanges addEntriesFromDictionary:self.unsavedObjectIDsToChanges];
        [self flushChanges];
      }
      NSURL *assetURL = [photoAsset valueForProperty: ALAssetPropertyAssetURL];
      DFCameraRollPhotoAsset *asset = [DFCameraRollPhotoAsset
                                       createWithALAsset:photoAsset
                                       inContext:self.managedObjectContext];
      NSDate *assetDate = [asset creationDateInUTC];
      [self.knownNotFoundURLs removeObject:assetURL];
      
      // We have this asset in our DB, see if it matches what we expect
      if ([self.knownPhotos.photoURLSet containsObject:assetURL]) {
        // Check the actual asset hash against our stored date, if it doesn't match, delete and recreate the DFPhoto with new info.
        
        if (![assetDate isEqual:self.knownAndFoundURLsToDates[assetURL]]){
          NSDictionary *changes = [self assetDataChangedForALAsset:photoAsset];
          [self.unsavedObjectIDsToChanges addEntriesFromDictionary:changes];
          // set to the new known date
          self.knownAndFoundURLsToDates[assetURL] = assetDate;
        } {
          // If we found what we expected, then delete the one we just created since its a dup
          [self.managedObjectContext deleteObject:asset];
        }
      } else {//(![knownAndFoundURLs containsObject:assetURLString])
        DFPhoto *newPhoto = [DFPhoto createWithAsset:asset
                                              userID:[[DFUser currentUser] userID]
                                           inContext:self.managedObjectContext];
        
        // store information about the new photo to notify
        self.unsavedObjectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
        // add to list of knownURLs so we don't duplicate add it
        // in either case, add mappings
        [self.foundURLs addObject:assetURL];
        self.knownAndFoundURLsToDates[assetURL] = assetDate;
      }
    } else {
      [groupObjectIDsToChanges addEntriesFromDictionary:self.unsavedObjectIDsToChanges];
      DDLogInfo(@"...all assets in group enumerated, changes: \n%@", [self changeTypesToCountsForChanges:groupObjectIDsToChanges].description);
      [self.allObjectIDsToChanges addEntriesFromDictionary:groupObjectIDsToChanges];
      [groupObjectIDsToChanges removeAllObjects];
    }
  };
}


- (NSDictionary *)assetDataChangedForALAsset:(ALAsset *)asset
{
  NSMutableDictionary *objectIDsToChanges = [[NSMutableDictionary alloc] init];
  
  NSURL *assetURL = [asset valueForProperty:ALAssetPropertyAssetURL];
  DFPhoto *photoToRemove = [DFPhotoStore photoWithALAssetURLString:[assetURL absoluteString]
                                                           context:self.managedObjectContext];
  objectIDsToChanges[photoToRemove.objectID] = DFPhotoChangeTypeRemoved;
  [self.managedObjectContext deleteObject:photoToRemove];
  
  DFCameraRollPhotoAsset *photoAsset = [DFCameraRollPhotoAsset createWithALAsset:asset inContext:self.managedObjectContext];
  DFPhoto *newPhoto = [DFPhoto createWithAsset:photoAsset
                                        userID:[[DFUser currentUser] userID]
                                     inContext:self.managedObjectContext];
  objectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
  
  return objectIDsToChanges;
}

- (NSDictionary *)removePhotosNotFound:(NSSet *)photoURLsNotFound
{
  DDLogInfo(@"%lu photos in DB not present on device.", (unsigned long)photoURLsNotFound.count);
  NSMutableDictionary *objectIDsToChanges = [[NSMutableDictionary alloc] init];
  
  NSArray *photosToRemove;
  if ([UIDevice majorVersionNumber] >= 8) {
    NSMutableArray *phAssetIDs = [NSMutableArray new];
    for (NSURL *url in photoURLsNotFound) {
      [phAssetIDs addObject:[DFPHAsset localIdentifierFromURL:url]];
    }
    photosToRemove = [DFPhotoStore photosWithPHAssetIdentifiers:phAssetIDs context:self.managedObjectContext];
  } else {
    photosToRemove = [DFPhotoStore photosWithALAssetURLStrings:photoURLsNotFound.allObjects
                                                                context:self.managedObjectContext];
  }
  
  for (DFPhoto *photo in photosToRemove) {
    objectIDsToChanges[photo.objectID] = DFPhotoChangeTypeRemoved;
    [self.managedObjectContext deleteObject:photo];
  }
  
  return objectIDsToChanges;
}


- (void)flushChanges
{
  [self saveChanges:[self.unsavedObjectIDsToChanges copy]];
  [self.unsavedObjectIDsToChanges removeAllObjects];
}

- (void)saveChanges:(NSDictionary *)changes
{
  // save to the store so that the main thread context can pick it up
  NSError *error = nil;
  if (self.managedObjectContext.hasChanges) {
    DDLogInfo(@"Camera roll sync made changes.  Saving... ");
    if(![self.managedObjectContext save:&error]) {
      DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
      [NSException raise:@"Could not save camera roll sync changes." format:@"Error: %@",[error localizedDescription]];
    } else {
      [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFPhotoChangedNotificationName
                                                                    object:self
                                                                  userInfo:changes];
    }
  }
}


- (NSDictionary *)changeTypesToCountsForChanges:(NSDictionary *)changes
{
  NSMutableDictionary *changeTypesToCounts = [[NSMutableDictionary alloc] init];
  for (NSString *changeType in @[DFPhotoChangeTypeAdded, DFPhotoChangeTypeMetadata, DFPhotoChangeTypeRemoved]) {
    NSSet *keysForType = [changes keysOfEntriesPassingTest:^BOOL(id key, NSString *changeTypeForKey, BOOL *stop) {
      if ([changeTypeForKey isEqualToString:changeType]) return YES;
      return NO;
    }];
    changeTypesToCounts[changeType] = [NSNumber numberWithUnsignedInteger:keysForType.count];
  }
  
  return changeTypesToCounts;
}



- (NSManagedObjectContext *)managedObjectContext
{
  if (_managedObjectContext != nil) {
    return _managedObjectContext;
  }
  
  _managedObjectContext = [DFPhotoStore createBackgroundManagedObjectContext];
  return _managedObjectContext;
}

@end
