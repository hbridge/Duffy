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

@end

@implementation DFImageDownloadManager

static DFImageDownloadManager *defaultManager;

+ (DFImageDownloadManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
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
  
  // Get list of photo from image store
  NSSet *fulfilledThumbs = [self.imageStore getPhotoIdsForType:DFImageThumbnail];

  NSSet *fulfilledFulls = [self.imageStore getPhotoIdsForType:DFImageThumbnail];

  NSMutableArray *thumbsToDownload = [NSMutableArray new];
  NSMutableArray *fullsToDownload = [NSMutableArray new];
  
  // Figure out what we need to download
  for (DFPeanutFeedObject *photoObject in remotePhotos) {
    if (![fulfilledThumbs containsObject:@(photoObject.id)] && ![photoObject.thumb_image_path isEqualToString:@""]) {
      [thumbsToDownload addObject:photoObject];
    }
    
    if (![fulfilledFulls containsObject:@(photoObject.id)] && ![photoObject.full_image_path isEqualToString:@""]) {
      [fullsToDownload addObject:photoObject];
    }
  }
  
  // Put in http requets for each image
  for (DFPeanutFeedObject *photoObject in thumbsToDownload) {
    [self getImageDataForPath:photoObject.thumb_image_path withCompletionBlock:^(UIImage *image, NSError *error) {
      [self.imageStore setImage:image type:DFImageThumbnail forID:photoObject.id completion:nil];
    }];
  }
  
  for (DFPeanutFeedObject *photoObject in fullsToDownload) {
    [self getImageDataForPath:photoObject.full_image_path withCompletionBlock:^(UIImage *image, NSError *error) {
      [self.imageStore setImage:image type:DFImageFull forID:photoObject.id completion:nil];
    }];
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
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    @autoreleasepool {
      NSURL *url = [[[DFUser currentUser] serverURL]
                    URLByAppendingPathComponent:path];
      DDLogVerbose(@"Getting image data at: %@", url);
      
      NSMutableURLRequest *downloadRequest = [[NSMutableURLRequest alloc]
                                              initWithURL:url
                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                              timeoutInterval:30.0];
      AFHTTPRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:downloadRequest];
      requestOperation.queuePriority = NSOperationQueuePriorityHigh; // image downloads are high priority
      
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
  });
}

@end
