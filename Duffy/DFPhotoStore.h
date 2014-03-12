//
//  DFPhotoStore.h
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DBRestClient.h>

@class ALAssetsLibrary;

@interface DFPhotoStore : NSObject <DBRestClientDelegate>

extern NSString *const DFPhotoStoreReadyNotification;

// Get the singleton store instance
+ (DFPhotoStore *)sharedStore;

// Get the shared ALAssets library for other model files
@property (readonly, strong, nonatomic) ALAssetsLibrary *assetsLibrary;

// Main accessors for data
- (NSArray *)cameraRoll;
- (NSArray *)photosWithUploadStatus:(BOOL)isUploaded;

// Core data stack
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

// Saves changes to disk
- (void)saveContext;

- (NSURL *)applicationDocumentsDirectory;




@end
