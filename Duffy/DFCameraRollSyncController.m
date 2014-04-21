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
    [self findNewAssets];
}

- (void)findNewAssets
{    
    NSMutableSet __block *knownAndFoundURLs;
    unsigned int __block groupNewAssets = 0;
    unsigned int __block totalNewAssets = 0;
    NSMutableDictionary __block *objectIDsToChanges = [[NSMutableDictionary alloc] init];
    
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *photoAsset, NSUInteger index, BOOL *stop) {
        if(photoAsset != NULL) {
            //TODO should also look for items in DB that have been desleted
            
            NSURL *assetURL = [photoAsset valueForProperty: ALAssetPropertyAssetURL];
#ifdef DEBUG
            NSLog(@"Scanning asset: %@", assetURL.absoluteString);
#endif
            if (![knownAndFoundURLs containsObject:assetURL.absoluteString])
            {
                //NSLog(@"...asset is new, adding to database.");
                // we haven't seent this photo before, add it to our database
                // have to add on main thread, since CoreData is not thread safe
                DFPhoto *newPhoto = [NSEntityDescription
                                     insertNewObjectForEntityForName:@"DFPhoto"
                                     inManagedObjectContext:self.managedObjectContext];
                newPhoto.alAssetURLString = assetURL.absoluteString;
                newPhoto.creationDate = [photoAsset valueForProperty:ALAssetPropertyDate];
                
                // store information about the new photo to notify
                groupNewAssets++;
                objectIDsToChanges[newPhoto.objectID] = DFPhotoChangeTypeAdded;
                // add to list of knownURLs so we don't duplicate add it
                [knownAndFoundURLs addObject:assetURL.absoluteString];
            } else {
                //NSLog(@"...asset is not new.");
            }
        } else {
            NSLog(@"...all assets in group enumerated, %d new assets.", groupNewAssets);
            totalNewAssets += groupNewAssets;
        }
    };
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) {
    	if(group != nil) {
            // only want photos for now
            groupNewAssets = 0;
            [group setAssetsFilter:[ALAssetsFilter allPhotos]];
            NSLog(@"Enumerating %d assets in %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
    		[group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
    	} else {
            // save to the store so that the main thread context can pick it up
            NSError *error = nil;
            if (self.managedObjectContext.hasChanges) {
                NSLog(@"Camera roll sync made changes (%d new assets).  Saving... ", totalNewAssets);
                if(![self.managedObjectContext save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    [NSException raise:@"Could not save new photo object." format:@"Error: %@",[error localizedDescription]];
                } else {
                    // successfull save, post notification
                    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFPhotoChangedNotificationName
                                                                                  object:self
                                                                                userInfo:objectIDsToChanges];
                }
            }
            
            [DFAnalytics logCameraRollScanTotalAssets:knownAndFoundURLs.count
                                          addedAssets:totalNewAssets];
            dispatch_semaphore_signal(self.syncSemaphore);
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreCameraRollScanComplete object:self];
        }
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_semaphore_wait(self.syncSemaphore, DISPATCH_TIME_FOREVER);
        NSSet *dbKnownURLs = [self knownPhotoURLs];
        knownAndFoundURLs = [dbKnownURLs mutableCopy];
        
        [[[DFPhotoStore sharedStore] assetsLibrary]
         enumerateGroupsWithTypes:ALAssetsGroupLibrary | ALAssetsGroupAlbum | ALAssetsGroupSavedPhotos
         usingBlock:assetGroupEnumerator
         failureBlock: ^(NSError *error) {
             NSLog(@"Failure");
         }];
    });
}

- (void)findDeletedAssets
{
    
}

- (NSSet *)knownPhotoURLs
{
    return [[DFPhotoStore allPhotosCollectionUsingContext:self.managedObjectContext] photoURLSet];
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
