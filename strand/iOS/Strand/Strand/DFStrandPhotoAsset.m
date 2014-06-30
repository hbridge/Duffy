//
//  DFStrandPhotoAsset.m
//  Strand
//
//  Created by Henry Bridge on 6/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandPhotoAsset.h"


@implementation DFStrandPhotoAsset

@dynamic localURLString;
@dynamic remoteURLString;
@dynamic metadata;

@synthesize fullResolutionImage;
@synthesize fullScreenImage;
@synthesize highResolutionImage;
@synthesize thumbnail;
@synthesize hashString;
@synthesize location;

- (NSURL *)canonicalURL
{
  if (self.remoteURLString) return [NSURL URLWithString:self.remoteURLString];
  if (self.localURLString) return [NSURL URLWithString:self.localURLString];
  return nil;
}

- (NSDictionary *)metadata
{

  return nil;
}

- (CLLocation *)location
{

  return nil;
}

- (NSString *)hashString
{

  return nil;
}

- (NSDate *)creationDateForTimezone:(NSTimeZone *)timezone
{

  return nil;
}

- (UIImage *)imageResizedToLength:(CGFloat)length
{

  return nil;
}

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{

}

- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{

}

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{

}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{

}


@end
