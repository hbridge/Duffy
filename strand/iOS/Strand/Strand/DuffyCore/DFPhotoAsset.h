//
//  DFPhotoAsset.h
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CLLocation;

@interface DFPhotoAsset : NSManagedObject

// Access to the images
// Will block if the image needs to be loaded from somewhere.  Avoid access on main thread
@property (readonly, nonatomic, retain) NSURL *canonicalURL;
@property (readonly, nonatomic, retain) UIImage *fullResolutionImage;
@property (readonly, nonatomic, retain) UIImage *thumbnail; // 157x157 thumbnail
@property (readonly, nonatomic, retain) UIImage *highResolutionImage; //max 2048x2048, aspect fit
@property (readonly, nonatomic, retain) UIImage *fullScreenImage;

// Metadata accessors
@property (readonly, nonatomic, retain) NSDictionary *metadata;
@property (readonly, nonatomic, retain) CLLocation *location;
@property (readonly, nonatomic, retain) NSString *hashString;
/* The asset doesn't necessarily know what timezone it's in, so you have to give it one */
- (NSDate *)creationDateForTimezone:(NSTimeZone *)timezone;

// Access the underlying image sized to a specific size.  Blocking call, avoid on main thread.
- (UIImage *)imageResizedToFitSize:(CGSize)size;
- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length;

// Use these to access image data asynchronously
typedef void (^DFPhotoAssetLoadSuccessBlock)(UIImage *image);
typedef void (^DFPhotoAssetLoadFailureBlock)(NSError *error);

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;
- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock;


// Access image data.  Blocking call, avoid on main thread.
- (NSData *)thumbnailJPEGData;
- (NSData *)scaledJPEGDataWithSmallerDimension:(CGFloat)length compressionQuality:(float)quality;
- (NSData *)scaledJPEGDataResizedToFitSize:(CGSize)size compressionQuality:(float)quality;





@end
