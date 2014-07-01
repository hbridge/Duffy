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
#import "DFAnalytics.h"
#import "DFPhotoMetadataAdapter.h"
#import "DFPeanutPhoto.h"
#import "DFPhotoStore.h"
#import "DFPhotoResizer.h"

@implementation DFStrandPhotoAsset

@dynamic localURLString;
@dynamic photoID;
@dynamic storedMetadata;
@dynamic storedLocation;
@dynamic creationDate;
@synthesize hashString = _hashString;


+ (DFStrandPhotoAsset *)createAssetForImageData:(NSData *)imageData
                                    photoID:(DFPhotoIDType)photoID
                                   metadata:(NSDictionary *)metadata
                                   location:(CLLocation *)location
                               creationDate:(NSDate *)creationDate
                                  inContext:(NSManagedObjectContext *)context
{
  DFStrandPhotoAsset *newAsset = [NSEntityDescription
                                   insertNewObjectForEntityForName:[[self class] description]
                                   inManagedObjectContext:context];
  newAsset.photoID = photoID;
  newAsset.storedMetadata = metadata;
  newAsset.storedLocation = location;
  newAsset.creationDate = creationDate;
  
  NSURL *localFileURL = [DFStrandPhotoAsset localURLForPhotoID:photoID];
  [imageData writeToURL:localFileURL atomically:YES];
  newAsset.localURLString = localFileURL.absoluteString;
  
  return newAsset;
}

- (NSURL *)canonicalURL
{
  if (self.photoID) return [DFPhotoMetadataAdapter urlForPhotoID:self.photoID];
  if (self.localURLString) return [NSURL URLWithString:self.localURLString];
  return nil;
}

- (NSDictionary *)metadata
{
  return self.storedMetadata;
}

- (CLLocation *)location
{
  return self.storedLocation;
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
  [self ensureLocalDataAndCallback:^(NSURL *localFileURL, NSError *error) {
    if (!error) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @autoreleasepool {
          UIImage *loadedImage = [UIImage imageWithContentsOfFile:[localFileURL path]];
          successBlock(loadedImage);
        }
      });
    } else {
      failureBlock(error);
    }
  }];
}

typedef void (^CacheCompleteBlock)(NSURL *localFileURL, NSError *error);

- (void)ensureLocalDataAndCallback:(CacheCompleteBlock)completionBlock
{
  if (self.localURLString) {
    NSURL *fileURL = [NSURL URLWithString:self.localURLString];
    completionBlock(fileURL, nil);
  } else if (self.photoID > 0) {
    DFPhotoIDType photoID = self.photoID;
    DFPhotoMetadataAdapter *adapter = [[DFPhotoMetadataAdapter alloc] init];
    [adapter getPhoto:photoID completionBlock:^(DFPeanutPhoto *peanutPhoto,
                                                NSData *fullImageData,
                                                NSError *error) {
      [DFStrandPhotoAsset cacheImageData:fullImageData
                                metadata:[peanutPhoto metadataDictionary]
                          forAssetWithID:photoID];
      completionBlock([DFStrandPhotoAsset localURLForPhotoID:photoID], nil);
    }];
  } else {
    DDLogWarn(@"DFStrandPhotoAsset: attempting to load full image for asset without local URL or photoID.");
    completionBlock(nil, [NSError errorWithDomain:@"com.duffyapp.Strand.DFStrandPhotoAsset" code:-4 userInfo:nil]);
  }
}

- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self ensureLocalDataAndCallback:^(NSURL *localFileURL, NSError *error) {
    if (!error) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @autoreleasepool {
          DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:localFileURL];
          UIImage *image = [resizer aspectImageWithMaxPixelSize:157];
          successBlock([image thumbnailImage:157
                           transparentBorder:0
                                cornerRadius:0
                        interpolationQuality:kCGInterpolationLow]);
        }
      });
    } else {
      failureBlock(error);
    }
  }];
}

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self ensureLocalDataAndCallback:^(NSURL *localFileURL, NSError *error) {
    if (!error) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @autoreleasepool {
          DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:localFileURL];
          UIImage *image = [resizer aspectImageWithMaxPixelSize:2048];
          successBlock(image);
        }
      });
    } else {
      failureBlock(error);
    }
  }];
}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
               failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  [self ensureLocalDataAndCallback:^(NSURL *localFileURL, NSError *error) {
    if (!error) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @autoreleasepool {
          DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:localFileURL];
          UIImage *image = [resizer aspectImageWithMaxPixelSize:1136];
          successBlock(image);
        }
      });
    } else {
      failureBlock(error);
    }
  }];
}

+ (void)cacheImageData:(NSData *)imageData
          metadata:(NSDictionary *)metadata
    forAssetWithID:(DFPhotoIDType)photoID
{
  NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
  NSFetchRequest *reqeust = [NSFetchRequest fetchRequestWithEntityName:@"DFStrandPhotoAsset"];
  reqeust.predicate = [NSPredicate predicateWithFormat:@"photoID == %llu", photoID];
  reqeust.fetchLimit = 1;
  
  NSError *error;
  NSArray *result = [context executeFetchRequest:reqeust error:&error];
  if (result.count == 0 || error) {
    DDLogWarn(@"DFStrandPhotoAsset: attempted to cache data for assetWithID:%llu not found or error:%@",
              photoID, error.description);
    return;
  }

  DFStrandPhotoAsset *asset = result.firstObject;
  asset.storedMetadata = metadata;
  NSURL *localFileURL = [DFStrandPhotoAsset localURLForPhotoID:photoID];
  [imageData writeToURL:localFileURL atomically:YES];
  asset.localURLString = localFileURL.absoluteString;
  [context save:&error];
  if (error) {
  #ifdef DEBUG
    [NSException raise:@"Couldn't save store after caching photo" format:@"%@",error.description];
  #else
    DDLogError(@"DFStrandPhotoAsset: couldn't save store after caching photo: %@", error.description);
  #endif
  }
}

+ (NSURL *)localURLForPhotoID:(DFPhotoIDType)photoID
{
  // if we have an actual photo id, that's used in the path
  NSString *filename;
  if (photoID != 0) {
    filename = [NSString stringWithFormat:@"%llu.jpg", photoID];
  } else {
    // otherwise, create a unique one
    CFUUIDRef newUniqueID = CFUUIDCreate (kCFAllocatorDefault);
    CFStringRef newUniqueIDString = CFUUIDCreateString (kCFAllocatorDefault, newUniqueID);
    filename = [NSString stringWithFormat:@"%@.jpg", newUniqueIDString];
  }
  
  return [[DFPhotoStore localFullImagesDirectoryURL]
          URLByAppendingPathComponent:filename];
}

- (NSData *)thumbnailJPEGData
{
  return UIImageJPEGRepresentation(self.thumbnail, 0.8);
}

- (NSData *)JPEGDataWithImageLength:(CGFloat)length compressionQuality:(float)quality
{
  DFPhotoResizer *resizer = [[DFPhotoResizer alloc]
                             initWithURL:[NSURL URLWithString:self.localURLString]];
  UIImage *image = [resizer aspectImageWithMaxPixelSize:length];
  return UIImageJPEGRepresentation(image, 0.8);
}


@end
