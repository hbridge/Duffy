//
//  DFPhotoAsset.h
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DFImageManagerRequest.h"

@class DFPhoto;
@class CLLocation;

@interface DFPhotoAsset : NSManagedObject

@property (nonatomic, retain) DFPhoto *photo;

extern const CGFloat DFPhotoAssetDefaultThumbnailSize;
extern const CGFloat DFPhotoAssetHighQualitySize;
extern const CGFloat DFPhotoAssetDefaultJPEGCompressionQuality;

// Use these to access image data asynchronously
typedef void (^DFPhotoAssetLoadSuccessBlock)(UIImage *image);
typedef void (^DFPhotoDataLoadSuccessBlock)(NSData *data);
typedef void (^DFPhotoAssetLoadFailureBlock)(NSError *error);

// Metadata accessors
@property (readonly, nonatomic, retain) NSURL *canonicalURL;
// This gets pulled from the storedMetadata if it exists, if not pulls from asset
@property (nonatomic, retain, readonly) NSMutableDictionary *metadata;
// This is a cached version of the metadata set upon creation of this class
@property (nonatomic, retain) id storedMetadata;
@property (nonatomic, retain) CLLocation *location;
@property (readonly, nonatomic, retain) NSString *hashString;

- (NSDate *)creationDateInUTC;

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadUIImageForThumbnailOfSize:(NSUInteger)size
                         successBlock:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadImageResizedToLength:(CGFloat)length
                         success:(DFPhotoAssetLoadSuccessBlock)success
                         failure:(DFPhotoAssetLoadFailureBlock)failure;

- (UIImage *)imageForRequest:(DFImageManagerRequest *)request;

// Access image data.  Blocking call, avoid on main thread.
- (void)loadThubnailJPEGData:(DFPhotoDataLoadSuccessBlock)successBlock
                     failure:(DFPhotoAssetLoadFailureBlock)failure;
- (void)loadJPEGDataWithImageLength:(CGFloat)length
                 compressionQuality:(float)quality
                            success:(DFPhotoDataLoadSuccessBlock)success
                            failure:(DFPhotoAssetLoadFailureBlock)failure;

@end
