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
@dynamic photoID;
@dynamic storedMetadata;
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

+ (DFStrandPhotoAsset *)createAssetForPhotoID:(DFPhotoIDType)photoID
                                    inContext:(NSManagedObjectContext *)context
{
  DFStrandPhotoAsset *newAsset = [NSEntityDescription
                                  insertNewObjectForEntityForName:[[self class] description]
                                  inManagedObjectContext:context];
  newAsset.photoID = photoID;
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

- (NSURL *)localURL
{
  return [NSURL URLWithString:self.localURLString];
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
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      UIImage *loadedImage = [UIImage imageWithContentsOfFile:[self.localURL path]];
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
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:self.localURL];
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
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:self.localURL];
      UIImage *image = [resizer aspectImageWithMaxPixelSize:2048];
      successBlock(image);
    }
  });
}

- (void)loadFullScreenImage:(DFPhotoAssetLoadSuccessBlock)successBlock
               failureBlock:(DFPhotoAssetLoadFailureBlock)failureBlock
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      DFPhotoResizer *resizer = [[DFPhotoResizer alloc] initWithURL:self.localURL];
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
  // if we have an actual photo id, that's used in the path
  
  // otherwise, create a unique one
  CFUUIDRef newUniqueID = CFUUIDCreate (kCFAllocatorDefault);
  CFStringRef newUniqueIDString = CFUUIDCreateString (kCFAllocatorDefault, newUniqueID);
  NSString *filename = [NSString stringWithFormat:@"%@.jpg", newUniqueIDString];
  
  return [[self localImagesDirectoryURL]
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
