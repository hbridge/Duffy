//
//  DFPhotoAsset.h
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DFPhoto;
@class CLLocation;

@interface DFPhotoAsset : NSManagedObject

@property (nonatomic, retain) DFPhoto *photo;

// Use these to access image data asynchronously
typedef void (^DFPhotoAssetLoadSuccessBlock)(UIImage *image);
typedef void (^DFPhotoDataLoadSuccessBlock)(NSData *data);
typedef void (^DFPhotoAssetLoadFailureBlock)(NSError *error);

// Metadata accessors
@property (readonly, nonatomic, retain) NSURL *canonicalURL;
// This gets pulled from the storedMetadata if it exists, if not pulls from asset
@property (nonatomic, retain, readonly) NSDictionary *metadata;
// This is a cached version of the metadata set upon creation of this class
@property (nonatomic, retain) id storedMetadata;
@property (nonatomic, retain) CLLocation *location;
@property (readonly, nonatomic, retain) NSString *hashString;
/* Returns the asset's  creation date for the given timezone.  Usually UTC will be specified */
- (NSDate *)creationDateForTimeZone:(NSTimeZone *)timezone;

/* Returns the asset's creation date for the local timezone it was taken in */
- (NSDate *)creationDateInAssetTimeZone;

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadImageResizedToLength:(CGFloat)length
                         success:(DFPhotoAssetLoadSuccessBlock)success
                         failure:(DFPhotoAssetLoadFailureBlock)failure;

// Access image data.  Blocking call, avoid on main thread.
- (void)loadThubnailJPEGData:(DFPhotoDataLoadSuccessBlock)successBlock
                     failure:(DFPhotoAssetLoadFailureBlock)failure;
- (void)loadJPEGDataWithImageLength:(CGFloat)length
                 compressionQuality:(float)quality
                            success:(DFPhotoDataLoadSuccessBlock)success
                            failure:(DFPhotoAssetLoadFailureBlock)failure;

@end
