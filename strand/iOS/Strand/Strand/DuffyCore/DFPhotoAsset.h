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

extern const CGFloat DFPhotoAssetDefaultThumbnailSize;
extern const CGFloat DFPhotoAssetHighQualitySize;
extern const CGFloat DFPhotoAssetDefaultJPEGCompressionQuality;

// Use these to access image data asynchronously
typedef void (^DFPhotoAssetLoadSuccessBlock)(UIImage *image);
typedef void (^DFPhotoDataLoadSuccessBlock)(NSData *data);
typedef void (^DFPhotoAssetLoadFailureBlock)(NSError *error);

@protocol DFPhotoAsset <NSObject>

@required
/* Required Metadata accessors */
@property (readonly, nonatomic, retain) NSURL *canonicalURL;
@property (readonly, nonatomic, retain) NSDate *creationDateInUTC;
@property (readonly, nonatomic, retain) CLLocation *location;
@property (readonly, nonatomic, retain) NSString *hashString;


/* Required Async Image Loading Accessors */
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
- (void)loadThubnailJPEGData:(DFPhotoDataLoadSuccessBlock)successBlock
                     failure:(DFPhotoAssetLoadFailureBlock)failure;
- (void)loadJPEGDataWithImageLength:(CGFloat)length
                 compressionQuality:(float)quality
                            success:(DFPhotoDataLoadSuccessBlock)success
                            failure:(DFPhotoAssetLoadFailureBlock)failure;

/* Required SYNC Image Accesssors.
 Do not call on main thread.
 */
- (UIImage *)imageForRequest:(DFImageManagerRequest *)request;

@end


@interface DFPhotoAsset : NSManagedObject

// The corresponding DFPhoto DB record
@property (nonatomic, retain) DFPhoto *photo;

// This is a cached version of the metadata set upon creation of this class
@property (nonatomic, retain) id storedMetadata;

// This gets pulled from the storedMetadata if it exists, if not pulls from asset
@property (nonatomic, retain, readonly) NSMutableDictionary *metadata;


@end
