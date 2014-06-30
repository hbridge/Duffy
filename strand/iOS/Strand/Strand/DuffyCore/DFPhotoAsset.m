//
//  DFPhotoAsset.m
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoAsset.h"


@implementation DFPhotoAsset

@synthesize canonicalURL;
@synthesize fullResolutionImage;
@synthesize fullScreenImage;
@synthesize highResolutionImage;
@synthesize thumbnail;
@synthesize hashString;
@synthesize location;
@synthesize metadata;


+ (NSError *)abstractClassError
{
  return [NSError errorWithDomain:@"com.DuffyApp.DuffyCore"
                             code:-1
                         userInfo:@{NSLocalizedDescriptionKey: @"DFPhotoAsset is an abstract class. This method must be implemented"}];
}

+ (void)abstractClassException
{
  [NSException raise:@"Attempting to call abstract DFPhotoAsset method" format:@"This DFPhotoAsset method is abstract.  You cannot call methods on it directly."];
}

- (NSDate *)creationDateForTimezone:(NSTimeZone *)timezone
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (UIImage *)imageResizedToFitSize:(CGSize)size
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSData *)scaledJPEGDataWithSmallerDimension:(CGFloat)length compressionQuality:(float)quality
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSData *)scaledJPEGDataResizedToFitSize:(CGSize)size compressionQuality:(float)quality
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSData *)thumbnailJPEGData
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}

- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}








@end
