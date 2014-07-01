//
//  DFPhotoStore.h
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPhotoCollection.h"
#import "DFPhoto.h"

@class ALAssetsLibrary, DFPhoto;

@interface DFPhotoStore : NSObject

// Get the store instance for the main thread
+ (DFPhotoStore *)sharedStore;

// Get a background context for use on background thread
+ (NSManagedObjectContext *)createBackgroundManagedObjectContext;

// Get the shared ALAssets library for other model files
@property (readonly, strong, nonatomic) ALAssetsLibrary *assetsLibrary;

// Main accessors for data
+ (DFPhotoCollection *)allPhotosCollectionUsingContext:(NSManagedObjectContext *)context; // used for accessing on another thread using a different context
- (DFPhotoCollection *)cameraRoll;
- (DFPhotoCollection *)mostRecentPhotos:(NSUInteger)maxCount;
- (DFPhoto *)mostRecentUploadedThumbnail;
- (DFPhotoCollection *)photosWithThumbnailUploadStatus:(BOOL)isThumbnailUploaded
                                      fullUploadStatus:(BOOL)isFullPhotoUploaded;
+ (DFPhotoCollection *)photosWithThumbnailUploadStatus:(BOOL)isThumbnailUploaded
                                      fullUploadStatus:(BOOL)isFullPhotoUploaded
                                             inContext:(NSManagedObjectContext *)context;
+ (DFPhotoCollection *)photosWithFullPhotoUploadStatus:(BOOL)isUploaded inContext:(NSManagedObjectContext *)context;
- (NSSet *)photosWithObjectIDs:(NSSet *)objectIDs;
+ (NSArray *)photosWithALAssetURLStrings:(NSArray *)assetURLStrings context:(NSManagedObjectContext *)context;
+ (DFPhoto *)photoWithALAssetURLString:(NSString *)assetURLString context:(NSManagedObjectContext *)context;
+ (NSArray *)photosWithPhotoIDs:(NSArray *)photoIDs
                    retainOrder:(BOOL)retainOrder
                      inContext:(NSManagedObjectContext *)context;
+ (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID inContext:(NSManagedObjectContext *)context;
- (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID;
- (NSArray *)photosWithPhotoIDs:(NSArray *)photoIDs retainOrder:(BOOL)retainOrder;

- (void)clearUploadInfo;

- (void)deletePhotoWithPhotoID:(DFPhotoIDType)photoID;

// Core data stack
+ (NSManagedObjectModel *)managedObjectModel;
+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

// Saves changes to disk
- (void)saveContext;

// wipe the store
- (void)resetStore;


+ (NSURL *)applicationDocumentsDirectory;
+ (NSURL *)localFullImagesDirectoryURL;
+ (NSURL *)localThumbnailsDirectoryURL;



@end
