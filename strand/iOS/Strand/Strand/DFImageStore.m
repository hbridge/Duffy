//
//  DFImageStore.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageStore.h"
#import "DFPhotoMetadataAdapter.h"

@interface DFImageStore()

@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;
@property (nonatomic, retain) NSMutableSet *remoteLoadsInProgress;
@property (nonatomic, retain) NSMutableDictionary *deferredCompletionBlocks;

@end

@implementation DFImageStore

@synthesize photoAdapter = _photoAdapter;

static DFImageStore *defaultStore;

+ (DFImageStore *)sharedStore {
  if (!defaultStore) {
    [self createCacheDirectories];
    defaultStore = [[super allocWithZone:nil] init];
  }
  return defaultStore;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedStore];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _deferredCompletionBlocks = [[NSMutableDictionary alloc] init];
    self.remoteLoadsInProgress = [[NSMutableSet alloc] init];
  }
  return self;
}

- (void)setImage:(UIImage *)image
            type:(DFImageType)type
           forID:(DFPhotoIDType)photoID
      completion:(SetImageCompletion)completion
{
  NSURL *url = [DFImageStore localURLForPhotoID:photoID type:type];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSData *data = UIImageJPEGRepresentation(image, 0.75);
      [data writeToURL:url atomically:YES];
      completion(nil);
    }
  });
}

- (void)setImageData:(NSData *)imageData
            type:(DFImageType)type
           forID:(DFPhotoIDType)photoID
      completion:(SetImageCompletion)completion
{
  NSURL *url = [DFImageStore localURLForPhotoID:photoID type:type];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      [imageData writeToURL:url atomically:YES];
      completion(nil);
    }
  });
}


- (void)imageForID:(DFPhotoIDType)photoID
              type:(DFImageType)type
        completion:(ImageLoadCompletionBlock)completionBlock
{
  NSURL *localUrl = [DFImageStore localURLForPhotoID:photoID type:type];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSData *imageData = [NSData dataWithContentsOfURL:localUrl];
      if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        completionBlock(image);
      } else {
        [self scheduleDeferredCompletion:completionBlock forPhotoID:photoID];
        if (![self.remoteLoadsInProgress containsObject:@(photoID)]) {
          [self.remoteLoadsInProgress addObject:@(photoID)];
          [self.photoAdapter getPhoto:photoID
                   withImageDataTypes:type
                      completionBlock:^(DFPeanutPhoto *peanutPhoto,
                                                                NSDictionary *imageData,
                                                                NSError *error) {
                        // cache the photo locally
                        NSData *data = imageData[@(type)];
                        [data writeToURL:localUrl atomically:YES];
                        UIImage *image = [UIImage imageWithData:data];
                        [self executeDefferredCompletionsWithImage:image forPhotoID:photoID];
          }];
        }
      }
    }
  });
}

- (void)scheduleDeferredCompletion:(ImageLoadCompletionBlock)completion forPhotoID:(DFPhotoIDType)photoID
{
  NSMutableArray *deferredForID = self.deferredCompletionBlocks[@(photoID)];
  if (!deferredForID) {
    deferredForID = [[NSMutableArray alloc] init];
    self.deferredCompletionBlocks[@(photoID)] = deferredForID;
  }
  
  [deferredForID addObject:[completion copy]];
}

- (void)executeDefferredCompletionsWithImage:(UIImage *)image forPhotoID:(DFPhotoIDType)photoID
{
  NSMutableArray *deferredForID = self.deferredCompletionBlocks[@(photoID)];
  for (ImageLoadCompletionBlock completion in deferredForID) {
    completion(image);
  }
  [deferredForID removeAllObjects];
}


#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
+ (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}



+ (void)createCacheDirectories
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSArray *directoriesToCreate = @[[[self localThumbnailsDirectoryURL] path],
                                   [[self localFullImagesDirectoryURL] path]];
  
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

#pragma mark - File Paths


+ (NSURL *)localURLForPhotoID:(DFPhotoIDType)photoID type:(DFImageType)type
{
  if (photoID == 0) return nil;
  // if we have an actual photo id, that's used in the path
  NSString *filename;
  filename = [NSString stringWithFormat:@"%llu.jpg", photoID];

  if (type == DFImageFull) {
    return [[DFImageStore localFullImagesDirectoryURL] URLByAppendingPathComponent:filename];
  } else if (type == DFImageThumbnail) {
    return [[DFImageStore localThumbnailsDirectoryURL] URLByAppendingPathComponent:filename];
  }
  
  return nil;
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

+ (NSURL *)localFullImagesDirectoryURL
{
  return [[self userLibraryURL] URLByAppendingPathComponent:@"fullsize"];
}

+ (NSURL *)localThumbnailsDirectoryURL
{
  return [[self userLibraryURL] URLByAppendingPathComponent:@"thumbnails"];
}

+ (NSError *)clearCache
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSArray *directoriesToDeleteAndCreate = @[[[self localThumbnailsDirectoryURL] path],
                                   [[self localFullImagesDirectoryURL] path]];
  
  for (NSString *path in directoriesToDeleteAndCreate) {
    if ([fm fileExistsAtPath:path]) {
      NSError *error;
      [fm removeItemAtPath:path error:&error];
      if (error) {
        DDLogError(@"Error deleting cache directory: %@, error: %@", path, error.description);
        return error;
      }
    }
  }
  [self createCacheDirectories];
  return nil;
}

#pragma mark - Network Adapters

- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) {
    _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
    
  }
  return _photoAdapter;
}


@end
