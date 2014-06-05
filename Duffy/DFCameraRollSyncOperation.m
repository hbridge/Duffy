//
//  DFCameraRollSyncOperation.m
//  Duffy
//
//  Created by Henry Bridge on 5/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollSyncOperation.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhotoCollection.h"
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "DFNotificationSharedConstants.h"
#import "DFAnalytics.h"
#import "DFDataHasher.h"
#import "NSNotificationCenter+DFThreadingAddons.h"

static int NumChangesFlushThreshold = 100;

@interface DFCameraRollSyncOperation()

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) DFPhotoCollection *knownPhotos;
@property (nonatomic) dispatch_semaphore_t enumerationCompleteSemaphore;
@property (nonatomic, retain) NSMutableSet *foundURLs;
@property (nonatomic, retain) NSMutableSet *knownNotFoundURLs;
@property (nonatomic, retain) NSMutableDictionary *knownAndFoundURLsToHashes;
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
    self.knownPhotos = [DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext];
    NSDictionary *changes = [self findChanges];
    
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    // gather info about total changes then send notification that a scan completed
    NSDictionary *changeTypesToCounts = [self changeTypesToCountsForChanges:changes];
    NSUInteger numAdded = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeAdded] unsignedIntegerValue];
    NSUInteger numDeleted = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeRemoved] unsignedIntegerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
      [DFAnalytics logCameraRollScanTotalAssets:self.knownPhotos.photoSet.count + numAdded - numDeleted
                                    addedAssets:numAdded];
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFPhotoStoreCameraRollUpdatedNotificationName
       object:self];
    });
  }
}

- (void)cancelled
{
  DDLogInfo(@"DFCameraRollSyncOperationCancelled.  Stopping.");
}


- (NSDictionary *)mapKnownPhotoURLsToHashes:(DFPhotoCollection *)knownPhotos
{
  NSMutableDictionary *mapping = [[NSMutableDictionary alloc] init];
  
  for (DFPhoto *photo in [knownPhotos photoSet]) {
    if (!photo.creationHashData) {
      photo.creationHashData = [photo currentHashData];
    }
    
    mapping[photo.alAssetURLString] = photo.creationHashData;
  }
  
  return mapping;
}

- (NSDictionary *)findChanges
{
  self.enumerationCompleteSemaphore = dispatch_semaphore_create(0);
  self.foundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownNotFoundURLs = [[self.knownPhotos photoURLSet] mutableCopy];
  self.knownAndFoundURLsToHashes = [[self mapKnownPhotoURLsToHashes:self.knownPhotos] mutableCopy];
  
  self.allObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  self.unsavedObjectIDsToChanges = [[NSMutableDictionary alloc] init];
  
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
  DDLogInfo(@"Scan complete.  Change summary for all groups: \n%@", [self changeTypesToCountsForChanges:self.allObjectIDsToChanges]);
  
  return self.allObjectIDsToChanges;
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
      NSString *assetURLString = [[photoAsset valueForProperty: ALAssetPropertyAssetURL] absoluteString];
      NSData *assetHash = [DFDataHasher hashDataForALAsset:photoAsset];
      [self.knownNotFoundURLs removeObject:assetURLString];
      
      
      // We have this asset in our DB, see if it matches what we expect
      if ([self.knownPhotos.photoURLSet containsObject:assetURLString]) {
        // Check the actual asset hash against our stored hash, if it doesn't match, delete and recreate the DFPhoto with new info.
        if (![assetHash isEqual:self.knownAndFoundURLsToHashes[assetURLString]]){
          NSDictionary *changes = [self assetDataChangedForAsset:photoAsset withNewHashData:assetHash];
          [self.unsavedObjectIDsToChanges addEntriesFromDictionary:changes];
          // set to the new known hash
          self.knownAndFoundURLsToHashes[assetURLString] = assetHash;
        }
      } else {//(![knownAndFoundURLs containsObject:assetURLString])
              // Check to see whether this is a dupe of an already known photo, if it's not, create a new one
        if (![[self.knownAndFoundURLsToHashes allValues] containsObject:assetHash]) {
          DFPhoto *newPhoto = [DFPhoto insertNewDFPhotoForALAsset:photoAsset
                                                     withHashData:assetHash
                                                        inContext:self.managedObjectContext];
          
          // store information about the new photo to notify
          self.unsavedObjectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
          // add to list of knownURLs so we don't duplicate add it
        }
        // in either case, add mappings
        [self.foundURLs addObject:assetURLString];
        self.knownAndFoundURLsToHashes[assetURLString] = assetHash;
      }
    } else {
      [groupObjectIDsToChanges addEntriesFromDictionary:self.unsavedObjectIDsToChanges];
      DDLogInfo(@"...all assets in group enumerated, changes: \n%@", [self changeTypesToCountsForChanges:groupObjectIDsToChanges].description);
      [self.allObjectIDsToChanges addEntriesFromDictionary:groupObjectIDsToChanges];
      [groupObjectIDsToChanges removeAllObjects];
    }
  };
}


- (NSDictionary *)assetDataChangedForAsset:(ALAsset *)asset withNewHashData:(NSData *)newHashData
{
  NSMutableDictionary *objectIDsToChanges = [[NSMutableDictionary alloc] init];
  
  NSString *assetURLString = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
  DFPhoto *photoToRemove = [DFPhotoStore photoWithALAssetURLString:assetURLString context:self.managedObjectContext];
  objectIDsToChanges[photoToRemove.objectID] = DFPhotoChangeTypeRemoved;
  [self.managedObjectContext deleteObject:photoToRemove];
  
  DFPhoto *newPhoto = [DFPhoto insertNewDFPhotoForALAsset:asset
                                             withHashData:newHashData
                                                inContext:self.managedObjectContext];
  objectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
  
  return objectIDsToChanges;
}

- (NSDictionary *)removePhotosNotFound:(NSSet *)photoURLsNotFound
{
  DDLogInfo(@"%lu photos in DB not present on device.", (unsigned long)photoURLsNotFound.count);
  NSMutableDictionary *objectIDsToChanges = [[NSMutableDictionary alloc] init];
  NSArray *photosToRemove = [DFPhotoStore photosWithALAssetURLStrings:photoURLsNotFound.allObjects context:self.managedObjectContext];
  
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
