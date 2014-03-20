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

@interface DFCameraRollSyncController()

@property (readonly, nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@end

@implementation DFCameraRollSyncController

@synthesize managedObjectContext = _managedObjectContext;


- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)asyncSyncToCameraRollWithCurrentKnownPhotoURLs:(NSSet *)knownURLs
{
    int __block newAssets = 0;
    
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *photoAsset, NSUInteger index, BOOL *stop) {
        if(photoAsset != NULL) {
            //TODO should also look for items in DB that have been desleted
            
            
            //NSLog(@"Scanning Camera Roll asset: %@...", result);
            NSURL *assetURL = [photoAsset valueForProperty: ALAssetPropertyAssetURL];
            if (![knownURLs containsObject:assetURL.absoluteString])
            {
                //NSLog(@"...asset is new, adding to database.");
                // we haven't seent this photo before, add it to our database
                // have to add on main thread, since CoreData is not thread safe
                DFPhoto *newPhoto = [NSEntityDescription
                                     insertNewObjectForEntityForName:@"DFPhoto"
                                     inManagedObjectContext:self.managedObjectContext];
                newPhoto.alAssetURLString = assetURL.absoluteString;
                newPhoto.creationDate = [photoAsset valueForProperty:ALAssetPropertyDate];
                newAssets++;
            } else {
                //NSLog(@"...asset is not new.");
            }
        } else {
            NSLog(@"All assets in Camera Roll enumerated, %d new assets.", newAssets);
            // save to the store so that the main thread context can pick it up
            NSError *error = nil;
            if (self.managedObjectContext.hasChanges) {
                NSLog(@"Camera roll sync made changes.  Saving... ");
                if(![self.managedObjectContext save:&error]) {
                    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                    [NSException raise:@"Could not save new photo object." format:@"Error: %@",[error localizedDescription]];
                }
            }
            
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreCameraRollScanComplete object:self];
        }
    };
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) {
    	if(group != nil) {
            // only want photos for now
            [group setAssetsFilter:[ALAssetsFilter allPhotos]];
            NSLog(@"Enumerating %d assets in %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
    		[group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
    	}
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [[[DFPhotoStore sharedStore] assetsLibrary] enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                          usingBlock:assetGroupEnumerator
                                        failureBlock: ^(NSError *error) {
                                            NSLog(@"Failure");
                                        }];
        
    });
}


- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [[DFPhotoStore sharedStore] persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

@end
