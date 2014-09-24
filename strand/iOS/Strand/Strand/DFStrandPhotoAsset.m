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

static NSMutableArray *idsBeingCached;

@implementation DFStrandPhotoAsset

@dynamic localURLString;
@dynamic storedLocation;
@dynamic creationDate;
@synthesize hashString = _hashString;

+ (void)initialize
{
  idsBeingCached = [[NSMutableArray alloc] init];
}

+ (DFStrandPhotoAsset *)createAssetForImageData:(NSData *)imageData
                                   metadata:(NSDictionary *)metadata
                                   location:(CLLocation *)location
                               creationDate:(NSDate *)creationDate
                                  inContext:(NSManagedObjectContext *)context
{
  DFStrandPhotoAsset *newAsset = [NSEntityDescription
                                   insertNewObjectForEntityForName:[[self class] description]
                                   inManagedObjectContext:context];
  newAsset.storedMetadata = metadata;
  newAsset.storedLocation = location;
  newAsset.creationDate = creationDate;
  
  [self createCacheDirectories];
  NSURL *localFileURL = [DFStrandPhotoAsset newLocalURLForPhoto];
  [imageData writeToURL:localFileURL atomically:YES];
  newAsset.localURLString = localFileURL.absoluteString;
  
  return newAsset;
}

- (CLLocation *)location
{
  return self.storedLocation;
}

- (NSString *)hashString
{
  if (!_hashString) {
    dispatch_semaphore_t thumbnailSemaphore = dispatch_semaphore_create(0);
    NSData __block *thumbnailData;
    [self loadThubnailJPEGData:^(NSData *data) {
      thumbnailData = data;
      dispatch_semaphore_signal(thumbnailSemaphore);
    } failure:^(NSError *error) {
      dispatch_semaphore_signal(thumbnailSemaphore);
    }];
    dispatch_semaphore_wait(thumbnailSemaphore, DISPATCH_TIME_FOREVER);
    NSData *hashData = [DFDataHasher hashDataForData:thumbnailData];
    _hashString = [DFDataHasher hashStringForHashData:hashData];
  }
  return _hashString;
}

- (NSURL *)localURL
{
  return [NSURL URLWithString:self.localURLString];
}

- (NSDate *)creationDateInUTC
{
  // We're tracking the timezone for Strand Photos right now so this shouldn't return anything
  // TODO(Derek): We really shouldn't do this, this should be corrected based on timezone
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
  NSURL *cachedLocalURL = self.localURL;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      UIImage *loadedImage = [UIImage imageWithContentsOfFile:[cachedLocalURL path]];
      successBlock(loadedImage);
    }
  });
  
}

- (BOOL)isCacheOperationUnderwayForID:(DFPhotoIDType)photoID
{
  return [idsBeingCached containsObject:@(photoID)];
}


- (void)loadUIImageForThumbnail:(DFPhotoAssetLoadSuccessBlock)successBlock
                   failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  NSURL *cachedLocalURL = self.localURL;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:cachedLocalURL];
      UIImage *image = [resizer aspectImageWithMaxPixelSize:157];
      successBlock([image thumbnailImage:157
                       transparentBorder:0
                            cornerRadius:0
                    interpolationQuality:kCGInterpolationLow]);
    }
  });
}

- (void)loadHighResImage:(DFPhotoAssetLoadSuccessBlock)successBlock
            failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  NSURL *cachedLocalURL = self.localURL;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:cachedLocalURL];
      UIImage *image = [resizer aspectImageWithMaxPixelSize:2048];
      successBlock(image);
    }
  });
}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
               failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  NSURL *cachedLocalURL = self.localURL;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:cachedLocalURL];
      UIImage *image = [resizer aspectImageWithMaxPixelSize:1136];
      if (image) {
        successBlock(image);
      } else {
        failureBlock([NSError
                      errorWithDomain:@"com.duffyapp.strand"
                      code:-7
                      userInfo:@{NSLocalizedDescriptionKey:
                                   [NSString stringWithFormat:@"Could not create read image at URL: %@",
                                    self.localURL]
                                 }]);
      }
    }
  });
  
}

+ (NSURL *)newLocalURLForPhoto
{
  CFUUIDRef newUniqueID = CFUUIDCreate (kCFAllocatorDefault);
  CFStringRef newUniqueIDString = CFUUIDCreateString (kCFAllocatorDefault, newUniqueID);
  NSString *filename = [NSString stringWithFormat:@"%@.jpg", newUniqueIDString];
  
  return [[self localImagesDirectoryURL]
          URLByAppendingPathComponent:filename];
}

- (void)loadThubnailJPEGData:(DFPhotoDataLoadSuccessBlock)successBlock failure:(DFPhotoAssetLoadFailureBlock)failure
{
  [self loadUIImageForThumbnail:^(UIImage *image) {
    @autoreleasepool {
      successBlock(UIImageJPEGRepresentation(image, 0.8));
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
  NSURL *cachedLocalURL = self.localURL;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc]
                                 initWithURL:cachedLocalURL];
      UIImage *image = [resizer aspectImageWithMaxPixelSize:length];
      success(UIImageJPEGRepresentation(image, 0.8));
    }
  });
}

+ (void)createCacheDirectories
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSArray *directoriesToCreate = @[[[
                                     self localImagesDirectoryURL] path],
                                   ];
  
  for (NSString *path in directoriesToCreate) {
    if (![fm fileExistsAtPath:path]) {
      NSError *error;
      [fm createDirectoryAtPath:path withIntermediateDirectories:NO
                     attributes:nil
                          error:&error];
      if (error) {
        DDLogError(@"Error creating cache directory: %@, error: %@", path, error.description);
        abort();
      }
    }
    
  }
}

+ (NSURL *)localImagesDirectoryURL
{
  return [[self userLibraryURL] URLByAppendingPathComponent:@"CameraPhotos" isDirectory:YES];
}

+ (NSURL *)userLibraryURL
{
  NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
  
  if ([paths count] > 0)
  {
    return [paths objectAtIndex:0];
  }
  return nil;
}


@end
