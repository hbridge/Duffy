//
//  DFPHAsset.m
//  Strand
//
//  Created by Henry Bridge on 9/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPHAsset.h"
#import <CoreLocation/CoreLocation.h>
#import <Photos/Photos.h>
#import "DFDataHasher.h"
#import "DFCGRectHelpers.h"
#import "DFAssetCache.h"
#import "UIDevice+DFHelpers.h"
#import "UIImage+Resize.h"

@interface DFPHAsset()


@end

@implementation DFPHAsset

@dynamic localIdentifier;
@synthesize asset = _asset;

static dispatch_queue_t localImageReuestQueue;

+ (void)initialize
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if ([UIDevice majorVersionNumber] >= 8) {
      dispatch_queue_attr_t queue_attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
      localImageReuestQueue = dispatch_queue_create("imageRequestQueue", queue_attr);
    }
  });
}

+ (DFPHAsset *)createWithPHAsset:(PHAsset *)asset
                       inContext:(NSManagedObjectContext *)managedObjectContext
{
  DFPHAsset *newAsset = [NSEntityDescription
                         insertNewObjectForEntityForName:NSStringFromClass([self class])
                         inManagedObjectContext:managedObjectContext];
  newAsset.localIdentifier = asset.localIdentifier;
  newAsset.asset = asset;
  
  return newAsset;
}

+ (NSURL *)URLForPHAssetLocalIdentifier:(NSString *)identifier
{
    // there is no such thing as a url for a PHAsset, so we make one up
  NSString *urlString = [NSString stringWithFormat:@"phassets://%@", identifier];
  return [NSURL URLWithString:urlString];
}

+ (NSString *)localIdentifierFromURL:(NSURL *)url
{
  return [[url absoluteString] stringByReplacingOccurrencesOfString:@"phassets://" withString:@""];
}

- (PHAsset *)asset
{
  if (!_asset) {
    _asset = [[DFAssetCache sharedCache] assetForLocalIdentifier:self.localIdentifier];
    if (!_asset) DDLogWarn(@"%@ warning asset for localID: %@ nil", self.class, self.localIdentifier);
  }
  
  return _asset;
}

- (NSURL*) canonicalURL
{
  return [self.class URLForPHAssetLocalIdentifier:self.localIdentifier];
}

// This gets pulled from the storedMetadata if it exists, if not pulls from asset
- (NSMutableDictionary *) metadata
{
  return  [self createMetadata:self.asset];
}

- (NSMutableDictionary *)createMetadata:(PHAsset *)asset
{
  CLLocation *location = self.asset.location;
  
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


// This is a cached version of the metadata set upon creation of this class
- (id) storedMetadata
{
  return self.metadata;
}


- (CLLocation *) location
{
  return self.asset.location;
}

- (NSString *) hashString
{
  PHImageRequestOptions *options = [PHImageRequestOptions new];
  options.synchronous = YES;
  
  NSData __block *resultImageData;
  [[PHImageManager defaultManager]
   requestImageDataForAsset:self.asset
   options:options
   resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
     resultImageData = imageData;
   }];
  
  NSString *hash = [DFDataHasher hashStringForHashData:[DFDataHasher hashDataForData:resultImageData]];
  return hash;
}

/* Returns the asset's creation date for the local timezone it was taken in */
- (NSDate *)creationDateInUTC
{
  return self.asset.creationDate;
}

+ (PHImageRequestOptions *)highQualityImageRequestOptions
{
  PHImageRequestOptions *options = [PHImageRequestOptions new];
  options.synchronous = YES;
  options.resizeMode = PHImageRequestOptionsResizeModeExact;
  options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
  return options;
}

+ (PHImageRequestOptions *)defaultImageRequestOptions
{
  return [self highQualityImageRequestOptions];
}

- (void)loadUIImageForSize:(CGSize)size
                    contentMode:(PHImageContentMode)contentMode
              success:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failure:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  // Cache the asset on the calling thread because self.asset accesses core data
  PHAsset *asset = self.asset;
  dispatch_async(localImageReuestQueue, ^{
    @autoreleasepool {
      [[PHImageManager defaultManager]
       requestImageForAsset:asset
       targetSize:size
       contentMode:contentMode
       options:[DFPHAsset defaultImageRequestOptions]
       resultHandler:^(UIImage *result, NSDictionary *info) {
         if (result) {
           DDLogVerbose(@"Requested aspect:%@ size %@ returned size: %@",
                        @(contentMode),
                        NSStringFromCGSize(size),
                        NSStringFromCGSize(result.size));
           successBlock(result);
         } else {
           DDLogError(@"%@: Error in getting image from PHImageManager. Creation date: %@, targetWidth: %f, targetHeight: %f, contentMode: %d,  info: %@ ",
                      self.class,
                      asset.creationDate,
                      size.width,
                      size.height,
                      (int)contentMode,
                      info);
           failureBlock(info[PHImageErrorKey]);
         }
       }];
    }
  });
}

- (void)loadUIImageForFullImage:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self loadUIImageForSize:PHImageManagerMaximumSize
               contentMode:PHImageContentModeAspectFill
                   success:successBlock
                   failure:failureBlock];
}

- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self loadUIImageForThumbnailOfSize:DFPhotoAssetDefaultThumbnailSize
                         successBlock:successBlock
                         failureBlock:failureBlock];
}

- (void)loadUIImageForThumbnailOfSize:(NSUInteger)size
                         successBlock:(DFPhotoAssetLoadSuccessBlock)successBlock
                         failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self loadUIImageForSize:CGSizeMake(size, size)
               contentMode:PHImageContentModeAspectFill
                   success:successBlock
                   failure:failureBlock];
}

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self loadUIImageForSize:CGSizeMake(DFPhotoAssetHighQualitySize, DFPhotoAssetHighQualitySize)
               contentMode:PHImageContentModeAspectFit
                   success:successBlock
                   failure:failureBlock];
}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
               failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self loadUIImageForSize:[[UIScreen mainScreen] bounds].size
               contentMode:PHImageContentModeAspectFit
                   success:successBlock
                   failure:failureBlock];
}
- (void)loadImageResizedToLength:(CGFloat)length
                         success:(DFPhotoAssetLoadSuccessBlock)success
                         failure:(DFPhotoAssetLoadFailureBlock)failure
{
  CGRect aspectRect = [DFCGRectHelpers
                       aspectFittedSize:CGSizeMake(self.asset.pixelWidth, self.asset.pixelHeight)
                       max:CGRectMake(0, 0, length, length)];
  [self loadUIImageForSize:aspectRect.size
               contentMode:PHImageContentModeAspectFit
                   success:success
                   failure:failure];
}

// Access image data.  Blocking call, avoid on main thread.
- (void)loadThubnailJPEGData:(DFPhotoDataLoadSuccessBlock)successBlock
                     failure:(DFPhotoAssetLoadFailureBlock)failure
{
  [self loadUIImageForThumbnail:^(UIImage *image) {
    @autoreleasepool {
      successBlock(UIImageJPEGRepresentation(image, DFPhotoAssetDefaultJPEGCompressionQuality));
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
  [self loadImageResizedToLength:length success:^(UIImage *image) {
    @autoreleasepool {
      success(UIImageJPEGRepresentation(image, quality));
    }
  } failure:^(NSError *error) {
    failure(error);
  }];
}


- (UIImage *)imageForRequest:(DFImageManagerRequest *)request
{
  PHAsset *asset = self.asset;
  PHImageRequestOptions *options = [self.class defaultImageRequestOptions];
  options.synchronous = YES;

  PHImageContentMode contentMode = PHImageContentModeDefault;
  if (request.contentMode == DFImageRequestContentModeAspectFit)
    contentMode = PHImageContentModeAspectFit;
  else if (request.contentMode == DFImageRequestContentModeAspectFill)
    contentMode = PHImageContentModeAspectFill;
  
  UIImage __block *result;
  [[PHImageManager defaultManager]
   requestImageForAsset:asset
   targetSize:request.size
   contentMode:contentMode
   options:[DFPHAsset defaultImageRequestOptions]
   resultHandler:^(UIImage *image, NSDictionary *info) {
     result = image;
     if (!image) {
       DDLogError(@"%@: Error in getting image from PHImageManager. Creation date: %@, targetWidth: %f, targetHeight: %f, contentMode: %d,  info: %@ ",
                  self.class,
                  asset.creationDate,
                  request.size.width,
                  request.size.height,
                  (int)contentMode,
                  info);
     }
   }];
  
  if (result &&
      request.deliveryMode == DFImageRequestOptionsDeliveryModeHighQualityFormat &&
      !CGSizeEqualToSize(result.size, request.size)) {
    UIViewContentMode contentMode = UIViewContentModeScaleAspectFill;
    if (request.contentMode == DFImageRequestContentModeAspectFit)
      contentMode = UIViewContentModeScaleAspectFit;
    result = [result croppedResizedImageWithContentMode:contentMode
                                          bounds:request.size
                            interpolationQuality:kCGInterpolationDefault];
    
  }
  
  return result;
}



@end
