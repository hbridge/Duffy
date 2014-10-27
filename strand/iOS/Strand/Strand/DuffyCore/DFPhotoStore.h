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

typedef enum {
  DFUploadStatusAny = 0,
  DFUploadStatusNotUploaded = 1,
  DFUploadStatusUploaded = 2,
} DFUploadStatus;

// Get the shared ALAssets library for other model files
@property (readonly, strong, nonatomic) ALAssetsLibrary *assetsLibrary;

// Main accessors for data
+ (DFPhotoCollection *)allPhotosCollectionUsingContext:(NSManagedObjectContext *)context; // used for accessing on another thread using a different context
- (DFPhotoCollection *)mostRecentPhotos:(NSUInteger)maxCount;
- (DFPhoto *)mostRecentUploadedThumbnail;
+ (DFPhotoCollection *)photosWithThumbnailUploadStatus:(DFUploadStatus)thumbnailStatus
                                      fullUploadStatus:(DFUploadStatus)fullStatus
                                     shouldUploadPhoto:(BOOL)shouldUploadPhoto
                                       photoIDRequired:(BOOL)photoIDRequired
                                             inContext:(NSManagedObjectContext *)context;
- (DFPhotoCollection *)photosWithUploadProcessedStatus:(BOOL)processedStatus
                                     shouldUploadImage:(BOOL)shouldUploadImage;
+ (DFPhotoCollection *)photosWithFullPhotoUploadStatus:(BOOL)isUploaded inContext:(NSManagedObjectContext *)context;
- (NSSet *)photosWithObjectIDs:(NSSet *)objectIDs;
+ (NSArray *)photosWithALAssetURLStrings:(NSArray *)assetURLStrings context:(NSManagedObjectContext *)context;
+ (DFPhoto *)photoWithALAssetURLString:(NSString *)assetURLString context:(NSManagedObjectContext *)context;
+ (NSArray *)photosWithPHAssetIdentifiers:(NSArray *)assetIds context:(NSManagedObjectContext *)context;;
+ (NSDictionary *)photosWithPhotoIDs:(NSArray *)photoIDs
                      inContext:(NSManagedObjectContext *)context;
+ (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID inContext:(NSManagedObjectContext *)context;
- (DFPhoto *)photoWithPhotoID:(DFPhotoIDType)photoID;
- (NSDictionary *)photosWithPhotoIDs:(NSArray *)photoIDs;
+ (NSArray *)photosWithoutPhotoIDInContext:(NSManagedObjectContext *)context;

- (void)clearUploadInfo;

- (void)deletePhotoWithPhotoID:(DFPhotoIDType)photoID;
- (void)saveImage:(UIImage *)image
     withMetadata:(NSDictionary *)metadata
  completionBlock:(void (^)(DFPhoto *newPhoto))completion;

// Core data stack
+ (NSManagedObjectModel *)managedObjectModel;
+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectContext *)managedObjectContext;

// Saves changes to disk
- (void)saveContext;

// wipe the store
+ (void)resetStore;

- (void)addAssetWithURL:(NSURL *) assetURL toPhotoAlbum:(NSString *) album;

- (void)saveImageToCameraRoll:(UIImage *)image
                 withMetadata:(NSDictionary *)metadata
                   completion:(void(^)(NSURL *assetURL, NSError *error))completion;

+ (void)fetchMostRecentSavedPhotoDate:(void (^)(NSDate *date))completion
                promptUserIfNecessary:(BOOL)promptUser;


- (void)markPhotosForUpload:(NSArray *)photoIDs;
- (void)cachePhotoIDsInImageStore:(NSArray *)photoIDs;


@end
