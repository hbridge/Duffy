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

@interface DFPHAsset()

@property (readonly, nonatomic, retain) PHAsset *asset;

@end

@implementation DFPHAsset

@dynamic localIdentifier;
@synthesize asset = _asset;

+ (DFPHAsset *)createWithPHAsset:(PHAsset *)asset
                       inContext:(NSManagedObjectContext *)managedObjectContext
{
  DFPHAsset *newAsset = [NSEntityDescription
                                      insertNewObjectForEntityForName:NSStringFromClass([self class])
                                      inManagedObjectContext:managedObjectContext];
  newAsset.localIdentifier = asset.localIdentifier;
  
  return newAsset;
}

+ (NSURL *)URLForPHAsset:(PHAsset *)asset
{
    // there is no such thing as a url for a PHAsset, so we make one up
  NSString *urlString = [NSString stringWithFormat:@"phassets://%@", asset.localIdentifier];
  return [NSURL URLWithString:urlString];
}

+ (NSString *)localIdentifierFromURL:(NSURL *)url
{
  return [[url absoluteString] stringByReplacingOccurrencesOfString:@"phassets://" withString:@""];
}

- (PHAsset *)asset
{
  if (!_asset) {
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[self.localIdentifier]
                                                                  options:nil];
    if (fetchResult.count > 0) {
      _asset = fetchResult.firstObject;
    }
  }
  
  return _asset;
}

- (NSURL*) canonicalURL
{
  return [self.class URLForPHAsset:self.asset];
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
  options.version = PHImageRequestOptionsVersionOriginal;
  options.resizeMode = PHImageRequestOptionsResizeModeFast;
  
  UIImage __block *imageResult;
  [[PHImageManager defaultManager]
   requestImageForAsset:self.asset
   targetSize:CGSizeMake(DFPhotoAssetDefaultThumbnailSize, DFPhotoAssetDefaultThumbnailSize)
   contentMode:PHImageContentModeAspectFill
   options:options
   resultHandler:^(UIImage *result, NSDictionary *info) {
     imageResult = result;
   }];
  
  NSString *hash = [DFDataHasher hashStringForHashData:[DFDataHasher hashDataForUIImage:imageResult]];
  return hash;
}


/* Returns the asset's  creation date for the given timezone.  Usually UTC will be specified */
- (NSDate *)creationDateForTimeZone:(NSTimeZone *)timezone
{
  return self.asset.creationDate;
}

/* Returns the asset's creation date for the local timezone it was taken in */
- (NSDate *)creationDateInAssetTimeZone
{
  return self.asset.creationDate;
}

+ (PHImageRequestOptions *)highQualityImageRequestOptions
{
  PHImageRequestOptions *options = [PHImageRequestOptions new];
  options.synchronous = NO;
  options.version = PHImageRequestOptionsVersionOriginal;
  options.resizeMode = PHImageRequestOptionsResizeModeExact;
  options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
  return options;
}

+ (PHImageRequestOptions *)defaultImageRequestOptions
{
  return nil;
}

- (void)loadUIImageForSize:(CGSize)size
                    contentMode:(PHImageContentMode)contentMode
              success:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failure:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [[PHImageManager defaultManager]
     requestImageForAsset:self.asset
     targetSize:size
     contentMode:contentMode
     options:[self.class defaultImageRequestOptions]
     resultHandler:^(UIImage *result, NSDictionary *info) {
       if (result) {
//         DDLogVerbose(@"Requested aspect:%@ size %@ returned size: %@",
//                      @(contentMode),
//                      NSStringFromCGSize(size),
//                      NSStringFromCGSize(result.size));
         successBlock(result);
       } else {
         failureBlock(info[PHImageErrorKey]);
       }
     }];
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



@end
