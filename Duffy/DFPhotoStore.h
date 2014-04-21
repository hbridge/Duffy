//
//  DFPhotoStore.h
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPhotoCollection.h"

@class ALAssetsLibrary;

@interface DFPhotoStore : NSObject

extern NSString *const DFPhotoStoreCameraRollUpdated;
extern NSString *const DFPhotoStoreCameraRollScanComplete;

// Get the store instance for the main thread
+ (DFPhotoStore *)sharedStore;

// Get the shared ALAssets library for other model files
@property (readonly, strong, nonatomic) ALAssetsLibrary *assetsLibrary;

// Main accessors for data
+ (DFPhotoCollection *)allPhotosCollectionUsingContext:(NSManagedObjectContext *)context; // used for accessing on another thread using a different context
- (DFPhotoCollection *)cameraRoll;
- (DFPhotoCollection *)photosWithUploadStatus:(BOOL)isUploaded;
- (NSSet *)photosWithObjectIDs:(NSSet *)objectIDs;
+ (NSArray *)photosWithALAssetURLStrings:(NSArray *)assetURLStrings context:(NSManagedObjectContext *)context;


// Core data stack
+ (NSManagedObjectModel *)managedObjectModel;
+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

// Saves changes to disk
- (void)saveContext;

// 

+ (NSURL *)applicationDocumentsDirectory;




@end
