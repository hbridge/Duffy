//
//  DFPhotoResizer.m
//  Strand
//
//  Created by Henry Bridge on 7/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoResizer.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import "UIImage+Resize.h"
#import "DFCGRectHelpers.h"


@interface DFPhotoResizer()

@property (nonatomic, retain) ALAsset *asset;
@property (nonatomic, retain) NSURL *url;

@end

@implementation DFPhotoResizer


- (id)initWithALAsset:(ALAsset *)asset
{
  self = [super init];
  if (self) {
    _asset = asset;
  }
  
  return self;
}

- (id)initWithURL:(NSURL *)imageURL
{
  self = [super init];
  if (self) {
    _url = imageURL;
  }
  
  return self;
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

- (CGImageSourceRef)createImageSourceRef
{
  CGImageSourceRef source;
  if (self.asset) {
    source = [self createImageSourceRefForAsset];
  } else {
    source = [self createImageSourceRefForURL];
  }
  return source;
}


- (CGImageRef)createAspectCGImageWithMaxPixelSize:(NSUInteger)size {
  NSParameterAssert(self.asset != nil || self.url != nil);
  NSParameterAssert(size > 0);
  
  CGImageSourceRef source= [self createImageSourceRef];
  if (!source) return nil;
  
  CGImageRef imageRef = [self createAspectCGImageWithSource:source maxPixelSize:size];
  CFRelease(source);
  
  
  return imageRef;
}

- (CGImageRef)createAspectCGImageWithSource:(CGImageSourceRef)source maxPixelSize:(NSUInteger)size
{
  NSDictionary *imageOptions =
  @{
    (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
    (NSString *)kCGImageSourceThumbnailMaxPixelSize : [NSNumber numberWithUnsignedInteger:size],
    (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
    };
  
  CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source,
                                                            0,
                                                            (__bridge CFDictionaryRef) imageOptions);
  return imageRef;
}

- (UIImage *)squareImageWithPixelSize:(NSUInteger)size {
  @autoreleasepool {
    UIImage *largeImage = [self aspectImageWithMaxPixelSize:1024];
    return [largeImage thumbnailImage:size
                    transparentBorder:0
                         cornerRadius:0
                 interpolationQuality:kCGInterpolationDefault];
  }
}

- (UIImage *)aspectFilledImageWithSize:(CGSize)size
{
  @autoreleasepool {
    CGImageSourceRef imageSource = [self createImageSourceRef];
    if (!imageSource) return nil;
    CGSize imageSize = [self.class sizeForImageSource:imageSource];
    CGSize fittingAspectSize = [DFCGRectHelpers aspectScaledSize:imageSize fittingSize:size];
    CGImageRef imageRef = [self createAspectCGImageWithSource:imageSource
                                                 maxPixelSize:MAX(fittingAspectSize.width,
                                                                  fittingAspectSize.height)];
    if (!imageRef) {
      CFRelease(imageSource);
      return nil;
    }
    UIImage *fittingAspectImage = [UIImage imageWithCGImage:imageRef];
    UIImage *cropped = [fittingAspectImage resizedImageWithContentMode:UIViewContentModeScaleAspectFill
                                                                bounds:size
                                                  interpolationQuality:kCGInterpolationDefault];
    
    CFRelease(imageRef);
    CFRelease(imageSource);
    
    return cropped;
  }
}

+ (CGSize)sizeForImageSource:(CGImageSourceRef)imageSource
{
  CGFloat width = 0.0f, height = 0.0f;
  CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
  if (imageProperties != NULL) {
    CFNumberRef widthNum  = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
    if (widthNum != NULL) {
      CFNumberGetValue(widthNum, kCFNumberCGFloatType, &width);
    }
    
    CFNumberRef heightNum = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
    if (heightNum != NULL) {
      CFNumberGetValue(heightNum, kCFNumberCGFloatType, &height);
    }
    
    CFRelease(imageProperties);
  }
  return CGSizeMake(width, height);
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

- (CGImageSourceRef)createImageSourceRefForURL
{
  CGImageSourceRef ref = CGImageSourceCreateWithURL((__bridge CFURLRef) self.url, NULL);
  if (!ref) DDLogWarn(@"%@ failed to create imagesource for %@", self.class, self.url);
  return ref;
}

@end
