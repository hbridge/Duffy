//
//  DFPhotoAsset.m
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoAsset.h"


@implementation DFPhotoAsset

#pragma mark - Property wrappers


- (UIImage *)thumbnail
{
  UIImage __block *loadedThumbnail;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  
  // Synchronously load the thunbnail
  // must dispatch this off the main thread or it will deadlock!
  dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self loadUIImageForThumbnail:^(UIImage *thumbnailImage) {
      loadedThumbnail = thumbnailImage;
      dispatch_semaphore_signal(sema);
    } failureBlock:^(NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
  });
  
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  
  return  loadedThumbnail;
}

- (UIImage *)fullResolutionImage
{
  UIImage __block *loadedFullImage;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  
  // Synchronously load the thunbnail
  // must dispatch this off the main thread or it will deadlock!
  dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self loadUIImageForFullImage:^(UIImage *image) {
      loadedFullImage = image;
      dispatch_semaphore_signal(sema);
    } failureBlock:^(NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
  });
  
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  return loadedFullImage;
}

- (UIImage *)highResolutionImage
{
  UIImage __block *loadedImage;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  
  // Synchronously load the thunbnail
  // must dispatch this off the main thread or it will deadlock!
  dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self loadHighResImage:^(UIImage *image) {
      loadedImage = image;
      dispatch_semaphore_signal(sema);
    } failureBlock:^(NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
  });
  
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  return loadedImage;
}

- (UIImage *)fullScreenImage
{
  UIImage __block *loadedImage;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  
  // Synchronously load the thunbnail
  // must dispatch this off the main thread or it will deadlock!
  dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self loadFullScreenImage:^(UIImage *image) {
      loadedImage = image;
      dispatch_semaphore_signal(sema);
    } failureBlock:^(NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
  });
  
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  return loadedImage;
}

#pragma mark Methods to Override from here down

- (NSURL *)canonicalURL
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSDictionary *)metadata
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

- (NSDate *)creationDateForTimezone:(NSTimeZone *)timezone
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (UIImage *)imageResizedToLength:(CGFloat)length
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

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [DFPhotoAsset abstractClassException];
}

#pragma mark


- (NSData *)thumbnailJPEGData
{
  [DFPhotoAsset abstractClassException];
  return nil;
}

- (NSData *)JPEGDataWithImageLength:(CGFloat)length compressionQuality:(float)quality
{
  [DFPhotoAsset abstractClassException];
  return nil;
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
