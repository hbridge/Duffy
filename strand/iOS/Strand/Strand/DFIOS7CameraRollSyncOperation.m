//
//  DFIOS7CameraRollSyncOperation.m
//  Strand
//
//  Created by Derek Parham on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFIOS7CameraRollSyncOperation.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "NSArray+DFHelpers.h"

#import "DFCameraRollPhotoAsset.h"
#import "DFNotificationSharedConstants.h"
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFStrandConstants.h"

@implementation DFIOS7CameraRollSyncOperation

- (ALAssetsLibraryAccessFailureBlock)libraryAccessFailureBlock {
  return ^(NSError *error) {
    DDLogError(@"Failed to enumerate photo groups: %@", error.localizedDescription);
    dispatch_semaphore_signal(self.enumerationCompleteSemaphore);
  };
}

- (NSDictionary *)findAssetChangesBetweenTimes:(NSDate *)startDate beforeEndDate:(NSDate *)endDate;
{
  // setup lists of objects
  self.enumerationCompleteSemaphore = dispatch_semaphore_create(0);
  self.foundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownNotFoundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownAndFoundURLsToDates = [[self mapKnownPhotoURLsToDates:self.knownPhotos] mutableCopy];
  
  self.allObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  self.unsavedObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  DDLogDebug(@"%@ finding ALAssetChanges", self.class);
  NSDate *timerStartDate = [NSDate date];
  // scan camera roll
  ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
  [library
   enumerateGroupsWithTypes: ALAssetsGroupSavedPhotos
   usingBlock:[self enumerateGroupsBlockSkippingGroupsNamed:nil startingAfter:startDate beforeEndDate:endDate]
   failureBlock:[self libraryAccessFailureBlock]];
  dispatch_semaphore_wait(self.enumerationCompleteSemaphore, DISPATCH_TIME_FOREVER);
  
  if (self.isCancelled) {
    return self.allObjectIDsToChanges;
  }
  [self flushChanges];
  
  // scan other items
  [library
   enumerateGroupsWithTypes: ALAssetsGroupAlbum
   usingBlock:[self enumerateGroupsBlockSkippingGroupsNamed:@[@"Camera Roll"] startingAfter:startDate beforeEndDate:endDate]
   failureBlock:[self libraryAccessFailureBlock]];
  
  if (self.isCancelled) {
    return self.allObjectIDsToChanges;
  }
  
  dispatch_semaphore_wait(self.enumerationCompleteSemaphore, DISPATCH_TIME_FOREVER);
  
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
  DDLogInfo(@"Scan complete.  Took %.02f Change summary for all groups: \n%@", [[NSDate date] timeIntervalSinceDate:timerStartDate], [self changeTypesToCountsForChanges:self.allObjectIDsToChanges]);
  
  return self.allObjectIDsToChanges;
}


- (ALAssetsLibraryGroupsEnumerationResultsBlock)enumerateGroupsBlockSkippingGroupsNamed:(NSArray *)groupNamesToSkip startingAfter:(NSDate *)startDate beforeEndDate:(NSDate *)endDate
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
      [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:[self photosEnumerationBlock:startDate beforeEndDate:endDate groupName:groupName]];
    } else {
      dispatch_semaphore_signal(self.enumerationCompleteSemaphore);
    }
  };
}



- (ALAssetsGroupEnumerationResultsBlock)photosEnumerationBlock:(NSDate *)startDate beforeEndDate:(NSDate *)endDate groupName:(NSString *)groupName
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
        if (self.isCancelled) {
          return;
        }
        [self flushChanges];
      }
      NSDate *assetDate = [photoAsset valueForProperty:ALAssetPropertyDate];
      
      if ((startDate && [assetDate compare:startDate] == NSOrderedAscending) || (endDate && [assetDate compare:endDate] == NSOrderedDescending)) {
        // This picture is outside our date range, so skip it
        return;
      }
      
      NSURL *assetURL = [photoAsset valueForProperty: ALAssetPropertyAssetURL];
      [self.knownNotFoundURLs removeObject:assetURL];
      
      BOOL savedFromSwap = [groupName isEqualToString:DFPhotosSaveLocationName];
      
      // We have this asset in our DB, see if it matches what we expect
      if ([self.knownPhotos.photoURLSet containsObject:assetURL]) {
        // Check the actual asset hash against our stored date, if it doesn't match,
        // delete and recreate the DFPhoto with new info.
        if (![assetDate isEqual:self.knownAndFoundURLsToDates[assetURL]]){
          NSDictionary *changes = [self assetDataChangedForALAsset:photoAsset savedFromSwap:savedFromSwap];
          [self.unsavedObjectIDsToChanges addEntriesFromDictionary:changes];
          // set to the new known date
          self.knownAndFoundURLsToDates[assetURL] = assetDate;
        }
      } else {//(![knownAndFoundURLs containsObject:assetURLString])
        
        DFCameraRollPhotoAsset *asset = [DFCameraRollPhotoAsset
                                         createWithALAsset:photoAsset
                                         inContext:self.managedObjectContext];
        DFPhoto *newPhoto = [DFPhoto createWithAsset:asset
                                              userID:[[DFUser currentUser] userID]
                                       savedFromSwap:savedFromSwap
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




- (NSDictionary *)assetDataChangedForALAsset:(ALAsset *)asset savedFromSwap:(BOOL)savedFromSwap
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
                                 savedFromSwap:savedFromSwap
                                     inContext:self.managedObjectContext];
  objectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
  
  return objectIDsToChanges;
}

- (NSArray *)photosToRemove:(NSSet *)photoURLsNotFound
{
  NSArray *urlStrings =
  [photoURLsNotFound.allObjects arrayByMappingObjectsWithBlock:^id(NSURL *url) {
    return url.absoluteString;
  }];
  return [DFPhotoStore photosWithALAssetURLStrings:urlStrings
                                                     context:self.managedObjectContext];
}

- (void)migrateAssets
{
}


@end
