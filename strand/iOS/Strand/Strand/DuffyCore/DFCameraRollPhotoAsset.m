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
#import "DFPhotoResizer.h"
#import "DFAssetCache.h"

static ALAssetsLibrary *defaultAssetLibrary;
const CGFloat DFPhotoAssetALAssetThumbnailSize = 157.0;

@interface DFCameraRollPhotoAsset()

@end


NSString *const DFCameraRollExtraMetadataKey = @"{DFCameraRollExtras}";
NSString *const DFCameraRollCreationDateKey = @"DateTimeCreated";

@implementation DFCameraRollPhotoAsset

@dynamic alAssetURLString;
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
  // TODO(Derek) Figure out how to do the full metadata pull and do another sync.
  
  // metadata = [[asset defaultRepresentation] metadata];
  newAsset.storedMetadata = [newAsset createMetadata:asset];
  return newAsset;
}

- (NSMutableDictionary *)createMetadata:(ALAsset *)asset
{
  CLLocation *location = [self.asset valueForProperty:ALAssetPropertyLocation];
 
  CLLocationCoordinate2D coords = location.coordinate;
  CLLocationDistance altitude = location.altitude;
  
  NSDictionary *latlongDict = @{@"Latitude": @(fabs(coords.latitude)),
                                @"LatitudeRef" : coords.latitude >= 0.0 ? @"N" : @"S",
                                @"Longitude" : @(fabs(coords.longitude)),
                                @"LongitudeRef" : coords.longitude >= 0.0 ? @"E" : @"W",
                                @"Altitude" : @(altitude),
                                };
  NSMutableDictionary *latLongMetadata = [NSMutableDictionary new];
  latLongMetadata[@"{GPS}"] = latlongDict;

  return latLongMetadata;
}

- (ALAsset *)asset
{
  NSURL *assetURL = [NSURL URLWithString:self.alAssetURLString];
  ALAsset __block *asset = [[DFAssetCache sharedCache] assetForURL:assetURL];
  if (asset) return asset;
  
  NSURL *asseturl = [NSURL URLWithString:self.alAssetURLString];
  ALAssetsLibrary *assetsLibrary = [DFCameraRollPhotoAsset sharedAssetsLibrary];
  
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  
  // must dispatch this off the main thread or it will deadlock!
  dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [assetsLibrary assetForURL:asseturl resultBlock:^(ALAsset *foundAsset) {
      asset = foundAsset;
      if (asset) {
        [[DFAssetCache sharedCache] setALAsset:asset forURL:assetURL];
      } else {
        DDLogWarn(@"%@ warning: could not get asset for URL:%@", self.class, assetURL);
      }
      dispatch_semaphore_signal(sema);
    } failureBlock:^(NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
  });
  
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  return asset;
}

- (NSURL *)canonicalURL
{
  return [NSURL URLWithString:self.alAssetURLString];
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


- (UIImage *)imageResizedToLength:(CGFloat)length
{
  DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithALAsset:self.asset];
  UIImage *resizedImage = [resizer aspectImageWithMaxPixelSize:length];
  return resizedImage;
}

- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [[DFCameraRollPhotoAsset sharedAssetsLibrary]
   assetForURL:[NSURL URLWithString:self.alAssetURLString]
   resultBlock:^(ALAsset *asset) {
     @autoreleasepool {
       if (asset.thumbnail) {
         successBlock([UIImage imageWithCGImage:asset.thumbnail]);
       } else {
         failureBlock(nil);
       }
     }
   } failureBlock:^(NSError *error) {
     failureBlock(error);
   }];
}

- (void)loadUIImageForThumbnailOfSize:(NSUInteger)size
                         successBlock:(DFPhotoAssetLoadSuccessBlock)successBlock
                         failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  if (size == DFPhotoAssetALAssetThumbnailSize) {
    // if the requested size is the default size (157) return that, as it's optimized
    [self loadUIImageForThumbnail:successBlock failureBlock:failureBlock];
    return;
  }
  
  DDLogWarn(@"Warning: gloadUIImageForThumbnailOfSize on DFCameraRollAsset.  Performance will suffer.");
  if (self.asset) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      @autoreleasepool {
        DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithALAsset:self.asset];
        UIImage *image = [resizer squareImageWithPixelSize:size];
        successBlock(image);
      }
    });
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

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self loadImageResizedToLength:2048.0
                         success:successBlock
                         failure:failureBlock];
}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
               failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  if (self.asset) {
    @autoreleasepool {
      CGImageRef imageRef = self.asset.defaultRepresentation.fullScreenImage;
      UIImage *image = [UIImage imageWithCGImage:imageRef];
      successBlock(image);
    }
  } else {
    failureBlock([NSError errorWithDomain:@"" code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
  }
}

- (void)loadImageResizedToLength:(CGFloat)length
                         success:(DFPhotoAssetLoadSuccessBlock)success
                         failure:(DFPhotoAssetLoadFailureBlock)failure
{
  if (self.asset) {
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithALAsset:self.asset];
      UIImage *image = [resizer aspectImageWithMaxPixelSize:length];
      success(image);
    }
  } else {
    failure([NSError errorWithDomain:@"" code:-1
                            userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
  }
}

#pragma mark - JPEGData Access


- (void)loadThubnailJPEGData:(DFPhotoDataLoadSuccessBlock)successBlock
                     failure:(DFPhotoAssetLoadFailureBlock)failure
{
  [[DFCameraRollPhotoAsset sharedAssetsLibrary]
   assetForURL:[NSURL URLWithString:self.alAssetURLString]
   resultBlock:^(ALAsset *asset) {
     @autoreleasepool {
       NSData *data = [self.class JPEGDataForCGImage:asset.thumbnail withQuality:0.7];
       if (data) successBlock(data);
       else failure (nil);
     }
   } failureBlock:^(NSError *error) {
     failure(error);
   }];
}

- (void)loadJPEGDataWithImageLength:(CGFloat)length
                 compressionQuality:(float)quality
                            success:(DFPhotoDataLoadSuccessBlock)success
                            failure:(DFPhotoAssetLoadFailureBlock)failure
{
  [[DFCameraRollPhotoAsset sharedAssetsLibrary]
   assetForURL:[NSURL URLWithString:self.alAssetURLString]
   resultBlock:^(ALAsset *asset) {
     @autoreleasepool {
       NSData *data = [self.class JPEGDataWithImageLength:length compressionQuality:quality asset:asset];
       if (data) success(data);
       else failure(nil);
     }
   } failureBlock:^(NSError *error) {
     failure(error);
   }];
}

+ (NSData *)JPEGDataWithImageLength:(CGFloat)length compressionQuality:(float)quality asset:(ALAsset *)asset
{
  DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithALAsset:asset];
  CGImageRef imageRef = [[resizer aspectImageWithMaxPixelSize:length] CGImage];
  NSData *outputData = [self JPEGDataForCGImage:imageRef withQuality:quality];
  
  return outputData;
}


+ (NSData *)JPEGDataForCGImage:(CGImageRef)imageRef withQuality:(float)quality
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

- (NSDate *)creationDateInUTC
{
  return [self.asset valueForProperty:ALAssetPropertyDate];
}


- (UIImage *)imageForRequest:(DFImageManagerRequest *)request
{
  UIImage *result;
  if (request.isDefaultThumbnail
      || request.deliveryMode == DFImageRequestOptionsDeliveryModeFastFormat) {
    result = [UIImage imageWithCGImage:self.asset.thumbnail];
  } else if (request.contentMode == DFImageRequestContentModeAspectFit) {
    DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithALAsset:self.asset];
    result = [resizer aspectImageWithMaxPixelSize:MAX(request.size.height, request.size.width)];
  } else if (request.contentMode == DFImageRequestContentModeAspectFill) {
    DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithALAsset:self.asset];
    result = [resizer aspectFilledImageWithSize:request.size];
  }
  
  return result;
}



@end
