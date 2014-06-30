//
//  DFCameraRollPhotoAsset.m
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraRollPhotoAsset.h"
#import <ImageIO/ImageIO.h>
#import <CoreLocation/CoreLocation.h>
#import "DFDataHasher.h"
#import "ALAsset+DFExtensions.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"

static ALAssetsLibrary *defaultAssetLibrary;

@interface DFCameraRollPhotoAsset()

@property (nonatomic, retain) ALAsset *asset;

@end


NSString *const DFCameraRollExtraMetadataKey = @"{DFCameraRollExtras}";
NSString *const DFCameraRollCreationDateKey = @"DateTimeCreated";

@implementation DFCameraRollPhotoAsset

@dynamic alAssetURLString;
@synthesize asset = _asset;
@synthesize hashString = _hashString;

+ (ALAssetsLibrary *)sharedAssetsLibrary
{
  if (!defaultAssetLibrary) {
    defaultAssetLibrary = [[ALAssetsLibrary alloc] init];
  }
  return defaultAssetLibrary;
}


+ (DFCameraRollPhotoAsset *)createWithALAsset:(ALAsset *)asset
                                    inContext:(NSManagedObjectContext *)managedObjectContext
{
  DFCameraRollPhotoAsset *newAsset = [NSEntityDescription
                       insertNewObjectForEntityForName:@"DFCameraRollPhotoAsset"
                       inManagedObjectContext:managedObjectContext];
  newAsset.alAssetURLString = [[asset.defaultRepresentation url] absoluteString];
  
  return newAsset;
}

- (ALAsset *)asset
{
  //if (!_asset) {
  ALAsset __block *returnAsset;
  NSURL *asseturl = [NSURL URLWithString:self.alAssetURLString];
  ALAssetsLibrary *assetsLibrary = [DFCameraRollPhotoAsset sharedAssetsLibrary];
  
  
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  
  // must dispatch this off the main thread or it will deadlock!
  dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [assetsLibrary assetForURL:asseturl resultBlock:^(ALAsset *asset) {
      returnAsset = asset;
      dispatch_semaphore_signal(sema);
    } failureBlock:^(NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
  });
  
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  //}
  return returnAsset;
  //return _asset;
}

- (NSURL *)canonicalURL
{
  return [NSURL URLWithString:self.alAssetURLString];
}

- (NSDictionary *)metadata
{
  return self.asset.defaultRepresentation.metadata;
}

- (NSDate *)creationDateForTimezone:(NSTimeZone *)timezone;
{
  return [self.asset creationDateForTimeZone:timezone];
}

- (NSString *)formatCreationDate:(NSDate *)date
{
  NSDateFormatter *dateFormatter = [NSDateFormatter EXIFDateFormatter];
  return [dateFormatter stringFromDate:date];
}

- (NSString *)hashString
{
  if (!_hashString) {
    NSData *hashData = [DFDataHasher hashDataForALAsset:self.asset];
    _hashString = [DFDataHasher hashStringForHashData:hashData];
  }
  return _hashString;
}

- (CLLocation *)location
{
  return [self.asset valueForProperty:ALAssetPropertyLocation];
}

#pragma mark - Image Accessors

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
  if (self.asset) {
    @autoreleasepool {
      UIImage *image = [self aspectImageWithMaxPixelSize:2048];
      return image;
    }
  } else {
    DDLogError(@"Could not get asset for photo: %@", self.description);
  }
  
  return nil;
}

- (UIImage *)fullScreenImage
{
  CGImageRef imageRef = self.asset.defaultRepresentation.fullScreenImage;
  UIImage *image = [UIImage imageWithCGImage:imageRef];
  return image;
}

- (UIImage *)imageResizedToFitSize:(CGSize)size
{
  UIImage *resizedImage = [self aspectImageWithMaxPixelSize:MAX(size.height, size.width)];
  return resizedImage;
}

- (CGSize)scaledSizeWithSmallerDimension:(CGFloat)length
{
  CGSize originalSize = self.asset.defaultRepresentation.dimensions;
  CGSize newSize;
  if (originalSize.height < originalSize.width) {
    CGFloat scaleFactor = length/originalSize.height;
    newSize = CGSizeMake(ceil(originalSize.width * scaleFactor), length);
  } else {
    CGFloat scaleFactor = length/originalSize.width;
    newSize = CGSizeMake(length, ceil(originalSize.height * scaleFactor));
  }
  
  return newSize;
}

- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length
{
  CGSize newSize = [self scaledSizeWithSmallerDimension:length];
  return [self imageResizedToFitSize:newSize];
}



- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  if (self.asset) {
    CGImageRef imageRef = [self.asset thumbnail];
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    successBlock(image);
  } else {
    failureBlock([NSError errorWithDomain:@"" code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
  }
}

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  if (self.asset) {
    @autoreleasepool {
      CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
      UIImage *image = [UIImage imageWithCGImage:imageRef
                                           scale:self.asset.defaultRepresentation.scale
                                     orientation:(UIImageOrientation)self.asset.defaultRepresentation.orientation];
      successBlock(image);
    }
  } else {
    failureBlock([NSError errorWithDomain:@"" code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
  }
}

// Helper methods for thumbnailForAsset:maxPixelSize:
static size_t getAssetBytesCallback(void *info, void *buffer, off_t position, size_t count) {
  ALAssetRepresentation *rep = (__bridge id)info;
  
  NSError *error = nil;
  size_t countRead = [rep getBytes:(uint8_t *)buffer fromOffset:position length:count error:&error];
  
  if (countRead == 0 && error) {
    // We have no way of passing this info back to the caller, so we log it, at least.
    NSLog(@"thumbnailForAsset:maxPixelSize: got an error reading an asset: %@", error);
  }
  
  return countRead;
}

static void releaseAssetCallback(void *info) {
  // The info here is an ALAssetRepresentation which we CFRetain in thumbnailForAsset:maxPixelSize:.
  // This release balances that retain.
  CFRelease(info);
}

// Returns a UIImage for the given asset, with size length at most the passed size.
// The resulting UIImage will be already rotated to UIImageOrientationUp, so its CGImageRef
// can be used directly without additional rotation handling.
// This is done synchronously, so you should call this method on a background queue/thread.

- (CGImageRef)createAspectCGImageWithMaxPixelSize:(NSUInteger)size {
  NSParameterAssert(self.asset != nil);
  NSParameterAssert(size > 0);
  
  CGImageSourceRef source = [self createImageSourceRefForAsset];
  
  NSDictionary *imageOptions =
  @{
    (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
    (NSString *)kCGImageSourceThumbnailMaxPixelSize : [NSNumber numberWithUnsignedInteger:size],
    (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
    };
  
  CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source,
                                                            0,
                                                            (__bridge CFDictionaryRef) imageOptions);
  CFRelease(source);
  
  
  return imageRef;
}

- (UIImage *)aspectImageWithMaxPixelSize:(NSUInteger)size {
  
  CGImageRef imageRef = [self createAspectCGImageWithMaxPixelSize:size];
  if (!imageRef) {
    return nil;
  }
  
  UIImage *toReturn = [UIImage imageWithCGImage:imageRef];
  CFRelease(imageRef);
  
  return toReturn;
}


- (CGImageSourceRef)createImageSourceRefForAsset
{
  ALAssetRepresentation *rep = [self.asset defaultRepresentation];
  
  CGDataProviderDirectCallbacks callbacks = {
    .version = 0,
    .getBytePointer = NULL,
    .releaseBytePointer = NULL,
    .getBytesAtPosition = getAssetBytesCallback,
    .releaseInfo = releaseAssetCallback,
  };
  
  CGDataProviderRef provider = CGDataProviderCreateDirect((void *)CFBridgingRetain(rep),
                                                          [rep size],
                                                          &callbacks);
  CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, NULL);
  CFRelease(provider);
  return source;
}

#pragma mark - JPEGData Access



- (NSData *)scaledJPEGDataWithSmallerDimension:(CGFloat)length compressionQuality:(float)quality
{
  CGSize newSize = [self scaledSizeWithSmallerDimension:length];
  return [self scaledJPEGDataResizedToFitSize:newSize compressionQuality:quality];
}

- (NSData *)scaledJPEGDataResizedToFitSize:(CGSize)size compressionQuality:(float)quality
{
  return [self aspectJPEGDataWithMaxPixelSize:MAX(size.height, size.width) compressionQuality:quality];
}

- (NSData *)aspectJPEGDataWithMaxPixelSize:(NSUInteger)size
                        compressionQuality:(float)quality {
  CGImageRef imageRef = [self createAspectCGImageWithMaxPixelSize:size];
  NSData *outputData = [self JPEGDataForCGImage:imageRef withQuality:quality];
  CGImageRelease(imageRef);
  
  return outputData;
}



- (NSData *)thumbnailJPEGData
{
  CGImageRef thumbnail = [self.asset thumbnail];
  return [self JPEGDataForCGImage:thumbnail withQuality:0.7];
}



- (NSData *)JPEGDataForCGImage:(CGImageRef)imageRef withQuality:(float)quality
{
  NSMutableData *outputData = [[NSMutableData alloc] init];
  CGImageDestinationRef destRef = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)outputData,
                                                                   kUTTypeJPEG,
                                                                   1,
                                                                   NULL);
  NSDictionary *properties = @{
                               (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(quality)
                               };
  
  CGImageDestinationSetProperties(destRef,
                                  (__bridge CFDictionaryRef)properties);
  
  CGImageDestinationAddImage(destRef,
                             imageRef,
                             NULL);
  CGImageDestinationFinalize(destRef);
  CFRelease(destRef);
  return outputData;
}

- (NSString *)localFilename
{
  ALAssetRepresentation *rep = [self.asset defaultRepresentation];
  NSString *fileName = [rep filename];
  return fileName;
}


@end
