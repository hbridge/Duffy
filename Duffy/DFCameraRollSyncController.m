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


@interface DFPhotoFingerprint : NSObject

@property (nonatomic, retain) NSString *alAssetURLString;
@property (nonatomic, retain) NSData *hash;

@end
@implementation DFPhotoFingerprint
@end



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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_semaphore_wait(self.syncSemaphore, DISPATCH_TIME_FOREVER);

        DFPhotoCollection *knownPhotos = [DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext];
        NSDictionary *changes = [self findChangesWithKnownPhotos:knownPhotos];
        
        
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


typedef void (^DFScanCompletionBlock)(NSDictionary *objectIDsToChanges);


- (NSDictionary *)findChangesWithKnownPhotos:(DFPhotoCollection *)knownPhotos
{
    dispatch_semaphore_t findNewAssetSemaphore = dispatch_semaphore_create(0);
    NSMutableSet __block *knownAndFoundURLs;
    NSMutableSet __block *knownNotFoundURLs;
    unsigned int __block groupNewAssets = 0;
    unsigned int __block totalNewAssets = 0;
    NSMutableDictionary __block *objectIDsToChanges = [[NSMutableDictionary alloc] init];
    
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *photoAsset, NSUInteger index, BOOL *stop) {
        if(photoAsset != NULL) {
            NSString *assetURLString = [[photoAsset valueForProperty: ALAssetPropertyAssetURL] absoluteString];
            #ifdef DEBUG
            NSLog(@"Scanning asset: %@", assetURLString);
            #endif
            [knownNotFoundURLs removeObject:assetURLString];
            if (![knownAndFoundURLs containsObject:assetURLString])
            {
                DFPhoto *newPhoto = [self addPhotoForAsset:photoAsset];
                
                // store information about the new photo to notify
                groupNewAssets++;
                objectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
                // add to list of knownURLs so we don't duplicate add it
                [knownAndFoundURLs addObject:assetURLString];
            }
        } else {
            NSLog(@"...all assets in group enumerated, %d new assets.", groupNewAssets);
            totalNewAssets += groupNewAssets;
        }
    };
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) {
    	if(group != nil) {
            groupNewAssets = 0;
            [group setAssetsFilter:[ALAssetsFilter allPhotos]]; // only want photos for now
            NSLog(@"Enumerating %d assets in %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
    		[group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
    	} else {
            dispatch_semaphore_signal(findNewAssetSemaphore);
        }
    };
    
    knownAndFoundURLs = [[knownPhotos photoURLSet] mutableCopy];
    knownNotFoundURLs = [[knownPhotos photoURLSet] mutableCopy];
    
    [[[DFPhotoStore sharedStore] assetsLibrary]
     enumerateGroupsWithTypes:ALAssetsGroupLibrary | ALAssetsGroupAlbum | ALAssetsGroupSavedPhotos
     usingBlock:assetGroupEnumerator
     failureBlock: ^(NSError *error) {
         NSLog(@"Failed to enumerate photo groups: %@", error.localizedDescription);
         dispatch_semaphore_signal(findNewAssetSemaphore);
     }];
    dispatch_semaphore_wait(findNewAssetSemaphore, DISPATCH_TIME_FOREVER);
    
    [objectIDsToChanges addEntriesFromDictionary:[self removePhotosNotFound:knownNotFoundURLs]];
    
    return objectIDsToChanges;
}

- (DFPhoto *)addPhotoForAsset:(ALAsset *)asset
{
    DFPhoto *newPhoto = [NSEntityDescription
                         insertNewObjectForEntityForName:@"DFPhoto"
                         inManagedObjectContext:self.managedObjectContext];
    newPhoto.alAssetURLString = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
    newPhoto.creationDate = [asset valueForProperty:ALAssetPropertyDate];
    return newPhoto;
}

- (NSDictionary *)removePhotosNotFound:(NSSet *)photoURLsNotFound
{
    NSLog(@"%lu photos in DB not present on device.", photoURLsNotFound.count);
    NSMutableDictionary *objectIDsToChanges = [[NSMutableDictionary alloc] init];
    NSArray *photosToRemove = [DFPhotoStore photosWithALAssetURLStrings:photoURLsNotFound context:self.managedObjectContext];
    
    for (DFPhoto *photo in photosToRemove) {
        NSLog(@"Photo with ALAsset: %@ no longer in camera roll.  Removing from DB", photo.alAssetURLString);
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
        NSLog(@"Camera roll sync made changes.  Saving... ");
        if(![self.managedObjectContext save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            [NSException raise:@"Could not save camera roll sync changes." format:@"Error: %@",[error localizedDescription]];
        } else {
            [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFPhotoChangedNotificationName
                                                                          object:self
                                                                        userInfo:accumulatedChanges];
        }
    }
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
