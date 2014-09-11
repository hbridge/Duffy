//
//  DFPhotoAsset.m
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoAsset.h"


@implementation DFPhotoAsset

@synthesize metadata;
@synthesize location;

@dynamic photo;
@dynamic storedMetadata;

#pragma mark Methods to Override from here down

- (NSMutableDictionary *)metadata
{
  return self.storedMetadata;
}

- (NSURL *)canonicalURL
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (CLLocation *)location
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSString *)hashString
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSDate *)creationDateForTimeZone:(NSTimeZone *)timezone
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSDate *)creationDateInAssetTimeZone
{
  [DFPhotoAsset abstractClassException];
  return nil;
}


- (void)loadImageResizedToLength:(CGFloat)length success:(DFPhotoAssetLoadSuccessBlock)success failure:(DFPhotoAssetLoadFailureBlock)failure
{
  [DFPhotoAsset abstractClassException];
}

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}

- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}

#pragma mark


- (void)loadThubnailJPEGData:(DFPhotoDataLoadSuccessBlock)successBlock failure:(DFPhotoAssetLoadFailureBlock)failure
{
  [DFPhotoAsset abstractClassException];
}

- (void)loadJPEGDataWithImageLength:(CGFloat)length compressionQuality:(float)quality success:(DFPhotoDataLoadSuccessBlock)success failure:(DFPhotoAssetLoadFailureBlock)failure
{
  [DFPhotoAsset abstractClassException];
}


#pragma mark - Abstract class helpers


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




@end
