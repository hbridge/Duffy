//
//  DFCameraRollSyncController.m
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollSyncController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhoto.h"
#import "DFPhotoStore.h"
#import "NSNotificationCenter+DFThreadingAddons.h"
#import "DFNotificationSharedConstants.h"
#import "DFAnalytics.h"
#import "DFDataHasher.h"


@interface DFCameraRollSyncController()

@property (readonly, nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (atomic) dispatch_semaphore_t syncSemaphore;

@end

@implementation DFCameraRollSyncController

@synthesize managedObjectContext = _managedObjectContext;


- (id)init
{
    self = [super init];
    if (self) {
        self.syncSemaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)asyncSyncToCameraRoll
{
    DDLogInfo(@"Camera roll sync requested.");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_semaphore_wait(self.syncSemaphore, DISPATCH_TIME_FOREVER);
        DDLogInfo(@"Camera roll sync beginning.");

        DFPhotoCollection *knownPhotos = [DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext];
        NSDictionary *knownPhotoURLsToHashes = [self mapKnownPhotoURLsToHashes:knownPhotos];
        NSDictionary *changes = [self findChangesWithKnownPhotos:knownPhotos urlsToHashes:knownPhotoURLsToHashes];
        
        
        // save changes
        [self saveChanges:changes];
        
        dispatch_semaphore_signal(self.syncSemaphore);
        
        // gather info about total changes then send notification that a scan completed
        NSDictionary *changeTypesToCounts = [self changeTypesToCountsForChanges:changes];
        NSUInteger numAdded = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeAdded] unsignedIntegerValue];
        NSUInteger numDeleted = [(NSNumber *)changeTypesToCounts[DFPhotoChangeTypeRemoved] unsignedIntegerValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            [DFAnalytics logCameraRollScanTotalAssets:knownPhotos.photoSet.count + numAdded - numDeleted
                                          addedAssets:numAdded];
            [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreCameraRollScanComplete object:self];
        });
    });
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

- (NSDictionary *)findChangesWithKnownPhotos:(DFPhotoCollection *)knownPhotos
                                 urlsToHashes:(NSDictionary *)knownPhotosURLsToHashes
{
    dispatch_semaphore_t findNewAssetSemaphore = dispatch_semaphore_create(0);
    NSMutableSet __block *knownAndFoundURLs = [[knownPhotos photoURLSet] mutableCopy];
    NSMutableSet __block *knownNotFoundURLs = [[knownPhotos photoURLSet] mutableCopy];
    NSMutableDictionary __block *knownAndFoundURLsToHashes = [knownPhotosURLsToHashes mutableCopy];
    
    NSMutableDictionary __block *groupObjectIDsToChanges = [[NSMutableDictionary alloc] init];
    NSMutableDictionary __block *objectIDsToChanges = [[NSMutableDictionary alloc] init];
    
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *photoAsset, NSUInteger index, BOOL *stop) {
#ifdef DEBUG
        //usleep(1000000/10 * 3);

#endif
        if(photoAsset != NULL) {
            NSString *assetURLString = [[photoAsset valueForProperty: ALAssetPropertyAssetURL] absoluteString];
            NSData *assetHash = [DFDataHasher hashDataForALAsset:photoAsset];
            [knownNotFoundURLs removeObject:assetURLString];
            
           
            // We have this asset in our DB, see if it matches what we expect
            if ([knownAndFoundURLs containsObject:assetURLString]) {
                // Check the actual asset hash against our stored hash, if it doesn't match, delete and recreate the DFPhoto with new info.
                if (![assetHash isEqual:knownAndFoundURLsToHashes[assetURLString]]){
                    NSDictionary *changes = [self assetDataChangedForAsset:photoAsset withNewHashData:assetHash];
                    [groupObjectIDsToChanges addEntriesFromDictionary:changes];
                    // set to the new known hash
                    knownAndFoundURLsToHashes[assetURLString] = assetHash;
                }
            } else {//(![knownAndFoundURLs containsObject:assetURLString])
                // Check to see whether this is a dupe of an already known photo, if it's not, create a new one
                if (![[knownAndFoundURLsToHashes allValues] containsObject:assetHash]) {
                    DFPhoto *newPhoto = [self addPhotoForAsset:photoAsset withHashData:assetHash];
                    
                    // store information about the new photo to notify
                    groupObjectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
                    // add to list of knownURLs so we don't duplicate add it
                }
                // in either case, add mappings
                [knownAndFoundURLs addObject:assetURLString];
                knownAndFoundURLsToHashes[assetURLString] = assetHash;
            }
        } else {
            DDLogInfo(@"...all assets in group enumerated, changes: \n%@", [self changeTypesToCountsForChanges:groupObjectIDsToChanges].description);
            [objectIDsToChanges addEntriesFromDictionary:groupObjectIDsToChanges];
            [groupObjectIDsToChanges removeAllObjects];
        }
    };
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) {
    	if(group != nil) {
            [group setAssetsFilter:[ALAssetsFilter allPhotos]]; // only want photos for now
            DDLogInfo(@"Enumerating %d assets in %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
    		[group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
    	} else {
            dispatch_semaphore_signal(findNewAssetSemaphore);
        }
    };

    [[[DFPhotoStore sharedStore] assetsLibrary]
     enumerateGroupsWithTypes: ALAssetsGroupSavedPhotos
     usingBlock:assetGroupEnumerator
     failureBlock: ^(NSError *error) {
         DDLogError(@"Failed to enumerate photo groups: %@", error.localizedDescription);
         dispatch_semaphore_signal(findNewAssetSemaphore);
     }];
    dispatch_semaphore_wait(findNewAssetSemaphore, DISPATCH_TIME_FOREVER);
    
    [objectIDsToChanges addEntriesFromDictionary:[self removePhotosNotFound:knownNotFoundURLs]];
    DDLogInfo(@"Scan complete.  Change summary for all groups: \n%@", [self changeTypesToCountsForChanges:objectIDsToChanges]);
    
    return objectIDsToChanges;
}

- (NSDictionary *)assetDataChangedForAsset:(ALAsset *)asset withNewHashData:(NSData *)newHashData
{
    NSMutableDictionary *objectIDsToChanges = [[NSMutableDictionary alloc] init];
    
    NSString *assetURLString = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
    DFPhoto *photoToRemove = [DFPhotoStore photoWithALAssetURLString:assetURLString context:self.managedObjectContext];
    objectIDsToChanges[photoToRemove.objectID] = DFPhotoChangeTypeRemoved;
    [self.managedObjectContext deleteObject:photoToRemove];
    
    DFPhoto *newPhoto = [self addPhotoForAsset:asset withHashData:newHashData];
    objectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
    
    return objectIDsToChanges;
}

- (DFPhoto *)addPhotoForAsset:(ALAsset *)asset withHashData:(NSData *)hashData
{
    DFPhoto *newPhoto = [NSEntityDescription
                         insertNewObjectForEntityForName:@"DFPhoto"
                         inManagedObjectContext:self.managedObjectContext];
    newPhoto.alAssetURLString = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
    newPhoto.creationDate = [asset valueForProperty:ALAssetPropertyDate];
    newPhoto.creationHashData = hashData;
    return newPhoto;
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

- (void)saveChanges:(NSDictionary *)accumulatedChanges
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
                                                                        userInfo:accumulatedChanges];
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
    
    NSPersistentStoreCoordinator *coordinator = [DFPhotoStore persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

@end
