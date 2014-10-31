//
//  DFImageDownloadManager.m
//  Strand
//
//  Created by Derek Parham on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageDownloadManager.h"

#import <AFNetworking.h>

#import "DFImageDiskCache.h"
#import "DFObjectManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFUser.h"


@interface DFImageDownloadManager()

@property (nonatomic, retain) RKObjectManager *objectManager;
@property (nonatomic, retain) DFPeanutFeedDataManager *dataManager;
@property (nonatomic, retain) DFImageDiskCache *imageStore;
@property (nonatomic, retain) NSOperationQueue *downloadQueue;

@end

@implementation DFImageDownloadManager

static DFImageDownloadManager *defaultManager;

+ (DFImageDownloadManager *)sharedManager {
  if (!defaultManager) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      defaultManager = [[super allocWithZone:nil] init];
    });
  }
  return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
    self.downloadQueue = [[NSOperationQueue alloc] init];
    self.objectManager = [DFObjectManager sharedManager];
    self.dataManager = [DFPeanutFeedDataManager sharedManager];
    self.imageStore = [DFImageDiskCache sharedStore];
  }
  return self;
}


- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(fetchNewImages)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)fetchNewImages
{
  // Get list of photo from feed manager
  NSArray *remotePhotos = [self.dataManager remotePhotos];
  
  DFImageType imageTypes[2] = {DFImageThumbnail, DFImageFull};
  for (int i = 0; i < 2; i++) {
    //figure out which have already been download for the type
    DFImageType imageType = imageTypes[i];
    NSSet *fulfilledForType = [self.imageStore getPhotoIdsForType:imageType];
    for (DFPeanutFeedObject *photoObject in remotePhotos) {
      NSString *imagePath;
      if (imageType == DFImageThumbnail) imagePath = photoObject.thumb_image_path;
      else if (imageType == DFImageFull) imagePath = photoObject.full_image_path;
      if (![fulfilledForType containsObject:@(photoObject.id)]
          && [imagePath isNotEmpty]) {
        // if there's an image path for and it hasn't been fulfilled, queue it for download
        [self
         getImageDataForPath:imagePath
         priority:NSOperationQueuePriorityLow // cache requests are low pri
         completionBlock:^(UIImage *image, NSError *error) {
           [self.imageStore
            setImage:image
            type:imageType
            forID:photoObject.id
            completion:nil];
         }];
      }
    }
  }
}

- (void)fetchImageDataForImageType:(DFImageType)type
                        andPhotoID:(DFPhotoIDType)photoID
                        completion:(ImageLoadCompletionBlock)completionBlock
{
  DFPeanutFeedObject *photoObject = [self.dataManager photoWithId:photoID];
  BOOL didDispatchForCompletion = NO;
  
  if (photoObject) {
    if (type == DFImageThumbnail && ![photoObject.thumb_image_path isEqualToString:@""]) {
      didDispatchForCompletion = YES;
      [self getImageDataForPath:photoObject.thumb_image_path
            withCompletionBlock:^(UIImage *image, NSError *error) {
              completionBlock(image);
      }];
    }
    
    if (type == DFImageFull && ![photoObject.full_image_path isEqualToString:@""]) {
      didDispatchForCompletion = YES;
      [self getImageDataForPath:photoObject.full_image_path
            withCompletionBlock:^(UIImage *image, NSError *error) {
              completionBlock(image);
      }];
    }
  } else {
    DDLogWarn(@"%@ asked to fetch photoID:%@ but dataManager returned nil.",
              self.class, @(photoID));
  }
  
  if (!didDispatchForCompletion) completionBlock(nil);
}

- (void)getImageDataForPath:(NSString *)path
        withCompletionBlock:(DFImageFetchCompletionBlock)completion
{
  [self getImageDataForPath:path
                   priority:NSOperationQueuePriorityHigh // interactive downloads are high priority
            completionBlock:completion];
}

- (void)getImageDataForPath:(NSString *)path
                   priority:(NSOperationQueuePriority)queuePriority
            completionBlock:(DFImageFetchCompletionBlock)completion
{
  
  NSURL *url = [[[DFUser currentUser] serverURL]
                URLByAppendingPathComponent:path];
  DDLogVerbose(@"Getting image data at: %@", url);
  
  NSMutableURLRequest *downloadRequest = [[NSMutableURLRequest alloc]
                                          initWithURL:url
                                          cachePolicy:NSURLRequestUseProtocolCachePolicy
                                          timeoutInterval:30.0];
  AFHTTPRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:downloadRequest];
  requestOperation.queuePriority = queuePriority;
  
  [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
    // Use my success callback with the binary data and MIME type string
    if (operation.responseData) {
      completion([UIImage imageWithData:operation.responseData], nil);
    } else {
      DDLogError(@"Error downloading image: %@", url);
      completion(nil, nil);
    }
  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    // Error callback
    DDLogError(@"Error downloading image: %@", url);
    completion(nil, error);
  }];
  [self.objectManager.HTTPClient enqueueHTTPRequestOperation:requestOperation];
}


@end
