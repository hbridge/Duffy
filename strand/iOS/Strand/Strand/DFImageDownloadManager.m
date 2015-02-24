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
#import "DFDeferredCompletionScheduler.h"
#import "DFSettings.h"
#import "DFPhotoStore.h"
#import "DFPeanutPhoto.h"

const NSUInteger maxConcurrentImageDownloads = 2;
const NSUInteger maxDownloadRetries = 3;

@interface DFImageDownloadManager()

@property (nonatomic, retain) DFPeanutFeedDataManager *dataManager;
@property (nonatomic, retain) DFImageDiskCache *imageStore;
@property (nonatomic, retain) DFDeferredCompletionScheduler *downloadScheduler;
@property (nonatomic) dispatch_semaphore_t photoFetchedSemaphore;

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
    self.downloadScheduler = [[DFDeferredCompletionScheduler alloc]
                              initWithMaxOperations:maxConcurrentImageDownloads
                              executionPriority:DISPATCH_QUEUE_PRIORITY_DEFAULT];
    self.dataManager = [DFPeanutFeedDataManager sharedManager];
    self.imageStore = [DFImageDiskCache sharedStore];
    self.photoFetchedSemaphore = dispatch_semaphore_create(1);
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
      if (![fulfilledForType containsObject:@(photoObject.id)]) {
        // If we don't have this image yet, queue it for download
        // It will automatically fill the cache
        [self fetchImageDataForImageType:imageType andPhotoID:photoObject.id priority:NSOperationQueuePriorityLow completion:nil];
      }
    }
  }
}

- (void)fetchImageDataForImageType:(DFImageType)type
                        andPhotoID:(DFPhotoIDType)photoID
                        completion:(ImageLoadCompletionBlock)completionBlock
{
  NSOperationQueuePriority priority = type == DFImageThumbnail ?
  NSOperationQueuePriorityVeryHigh : NSOperationQueuePriorityHigh; // thumbnails are highest
  [self fetchImageDataForImageType:type andPhotoID:photoID priority:priority completion:completionBlock];
}

- (void)fetchImageDataForImageType:(DFImageType)type
                        andPhotoID:(DFPhotoIDType)photoID
                          priority:(NSOperationQueuePriority)priority
                        completion:(ImageLoadCompletionBlock)completionBlock
{
  NSString *path = [self.dataManager imagePathForPhotoWithID:photoID ofType:type];
  BOOL didDispatchForCompletion = NO;
  
  if (path && [path length] > 0) {
    didDispatchForCompletion = YES;
    [self getImageDataForPath:path
                     priority:priority
              completionBlock:^(UIImage *image, NSError *error) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                  dispatch_semaphore_wait(self.photoFetchedSemaphore, DISPATCH_TIME_FOREVER);
                  
                  if (![[DFImageDiskCache sharedStore] haveAlreadyDownloadedPhotoID:photoID forType:type]) {
                    [[DFImageDiskCache sharedStore] setImage:image
                                                        type:type
                                                       forID:photoID
                                                  completion:^(NSError *error) {
                                                    dispatch_semaphore_signal(self.photoFetchedSemaphore);
                                                    
                                                    if (type == DFImageFull && [[DFSettings sharedSettings] autosaveToCameraRoll]) {
                                                      // This is async so fast
                                                      [self saveImageToCameraRoll:image photoID:photoID];
                                                    }
                                                    
                                                    if (completionBlock) completionBlock(image);
                                                  }];
                  } else {
                    dispatch_semaphore_signal(self.photoFetchedSemaphore);
                    if (completionBlock) completionBlock(image);
                  }
                });
              }];
  } else {
    DDLogWarn(@"%@ asked to fetch photoID:%@ but dataManager returned nil.",
              self.class, @(photoID));
  }
  
  if (!didDispatchForCompletion && completionBlock) completionBlock(nil);
}

/*
 * Not ideal here but no where else really
 */
- (void)saveImageToCameraRoll:(UIImage *)image photoID:(DFPhotoIDType)photoID
{
  DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] initWithFeedObject:[self.dataManager firstPhotoInAllStrandsWithId:photoID]];
  [[DFPhotoStore sharedStore]
   saveImageToCameraRoll:image
   withMetadata:peanutPhoto.metadataDictionary
   completion:^(NSURL *assetURL, NSError *error) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (error) {
         DDLogError(@"Unable to auto-save photo %llu to disk", photoID);
       } else {
         DDLogInfo(@"Successfully auto-saved photo %llu to disk", photoID);
       }
     });
   }];
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
  NSURL *url = [[[DFUser currentUser] imageServerURL]
                URLByAppendingPathComponent:path];
  
  // add the operation to our local download queue so we don't swamp the network with download
  // requests and prevent others from getting scheduled
  [self.downloadScheduler
   enqueueRequestForObject:url
   withPriority:queuePriority
   executeBlockOnce:^id{
     @autoreleasepool {
       AFHTTPRequestOperation *requestOperation = nil;
       for (int retryCount = 0; retryCount <= maxDownloadRetries; retryCount++) {
         usleep(retryCount * 2 * USEC_PER_SEC);
         DDLogVerbose(@"Getting image data at: %@", url);
         NSMutableURLRequest *downloadRequest = [[NSMutableURLRequest alloc]
                                                 initWithURL:url
                                                 cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                 timeoutInterval:15.0];
         requestOperation = [[AFImageRequestOperation alloc] initWithRequest:downloadRequest];
         requestOperation.queuePriority = queuePriority;
         [[[DFObjectManager sharedManager] HTTPClient] enqueueHTTPRequestOperation:requestOperation];
         [requestOperation waitUntilFinished];
         if (!requestOperation.error) {
           break;
         } else {
           DDLogError(@"%@ attempt %d image download failed: %@",
                      self.class, retryCount, requestOperation.error);
         }
       }
       
       NSMutableDictionary *result = [NSMutableDictionary new];
       if (requestOperation.responseData && !requestOperation.error) {
         UIImage *image = [UIImage imageWithData:requestOperation.responseData];
         if (image) {
           result[@"image"] = image;
         }
       }
       if (requestOperation.error) {
         result[@"error"] = requestOperation.error;
       }
       return result;
     }
   } completionHandler:^(NSDictionary *resultDict) {
     completion(resultDict[@"image"], resultDict[@"error"]);
   }];
}


@end
