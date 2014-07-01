//
//  DFStrandPhotoAsset.m
//  Strand
//
//  Created by Henry Bridge on 6/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandPhotoAsset.h"
#import "DFDataHasher.h"
#import "UIImage+Resize.h"

@implementation DFStrandPhotoAsset

@dynamic localURLString;
@dynamic remoteURLString;
@dynamic metadata;
@dynamic location;
@dynamic creationDate;
@synthesize hashString = _hashString;

- (NSURL *)canonicalURL
{
  if (self.remoteURLString) return [NSURL URLWithString:self.remoteURLString];
  if (self.localURLString) return [NSURL URLWithString:self.localURLString];
  return nil;
}

- (NSString *)hashString
{
  if (!_hashString) {
    NSData *hashData = [DFDataHasher hashDataForData:[self thumbnailJPEGData]];
    _hashString = [DFDataHasher hashStringForHashData:hashData];
  }
  return _hashString;
}

- (NSDate *)creationDateForTimezone:(NSTimeZone *)timezone
{
  // this DFStrand assets get their timezone set explicitly, so TZ correction should be unnecessary
  return self.creationDate;
}

- (UIImage *)imageResizedToLength:(CGFloat)length
{
  dispatch_semaphore_t loadSemaphore = dispatch_semaphore_create(0);
  UIImage __block *fullImage;
  [self loadUIImageForFullImage:^(UIImage *image) {
    fullImage = image;
    dispatch_semaphore_signal(loadSemaphore);
  } failureBlock:^(NSError *error) {
    DDLogWarn(@"Couldn't load full image: %@", error.description);
    dispatch_semaphore_signal(loadSemaphore);
  }];
  dispatch_semaphore_wait(loadSemaphore, DISPATCH_TIME_FOREVER);
  
  if (fullImage) return [fullImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit
                                                        bounds:CGSizeMake(length, length)
                                          interpolationQuality:kCGInterpolationDefault];
  
  return nil;
}

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  
}

- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{

}

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{

}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
               failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{

}


@end
