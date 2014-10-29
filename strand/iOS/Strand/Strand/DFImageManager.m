//
//  DFImageManager.m
//  Strand
//
//  Created by Henry Bridge on 10/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageManager.h"
#import "DFPhotoAsset.h"
#import "DFImageStore.h"
#import "DFImageDownloadManager.h"
#import "DFPhotoStore.h"
#import "DFPhotoResizer.h"

@interface DFImageManager()

@property (readonly, atomic, retain) NSMutableDictionary *deferredCompletionBlocks;
@property (readonly, atomic, retain) NSMutableDictionary *photoIDsToDeferredRequests;
@property (nonatomic) dispatch_semaphore_t deferredCompletionSchedulerSemaphore;
@property (readonly, atomic) dispatch_queue_t imageRequestQueue;
@property (readonly, atomic) dispatch_queue_t cacheRequestQueue;
@property (readonly, atomic, retain) NSMutableDictionary *imageRequestCache;
@property (nonatomic) dispatch_semaphore_t imageRequestCacheSemaphore;

@end

@implementation DFImageManager

@synthesize deferredCompletionBlocks = _deferredCompletionBlocks;

+ (DFImageManager *)sharedManager {
  static DFImageManager *defaultManager = nil;
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
    _deferredCompletionBlocks = [NSMutableDictionary new];
    _photoIDsToDeferredRequests = [NSMutableDictionary new];
    _deferredCompletionSchedulerSemaphore = dispatch_semaphore_create(1);
    dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, 0);
    _imageRequestQueue = dispatch_queue_create("ImageReqQueue", attrs);
    
    // setup the cache
    dispatch_queue_attr_t cache_attrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_DEFAULT, 0);
    _imageRequestQueue = dispatch_queue_create("ImageCacheReqQueue", cache_attrs);
    _imageRequestCache = [NSMutableDictionary new];
    _imageRequestCacheSemaphore = dispatch_semaphore_create(1);
    
    [self observeNotifications];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleLowMemory:)
                                               name:UIApplicationDidReceiveMemoryWarningNotification
                                             object:[UIApplication sharedApplication]];
}

- (void)handleLowMemory:(NSNotification *)note
{
  DDLogInfo(@"%@ got low memory warning. Clearing cache", self.class);
  [self clearCache];
}

- (void)imageForID:(DFPhotoIDType)photoID
     preferredType:(DFImageType)type
        completion:(ImageLoadCompletionBlock)completionBlock
{
  // for legacy interface, fake the size and content mode
  CGSize size;
  DFImageRequestContentMode contentMode;
  if (type == DFImageThumbnail) {
    size = CGSizeMake(DFPhotoAssetDefaultThumbnailSize, DFPhotoAssetDefaultThumbnailSize);
    contentMode = DFImageRequestContentModeAspectFill;
  } else {
    size = CGSizeMake(DFPhotoAssetHighQualitySize, DFPhotoAssetHighQualitySize);
    contentMode = DFImageRequestContentModeAspectFit;
  }
  
  [self imageForID:photoID
              size:size
       contentMode:contentMode
      deliveryMode:DFImageRequestOptionsDeliveryModeHighQualityFormat
        completion:completionBlock];
}

- (void)imageForID:(DFPhotoIDType)photoID
              size:(CGSize)size
       contentMode:(DFImageRequestContentMode)contentMode
      deliveryMode:(DFImageRequestDeliveryMode)deliveryMode
        completion:(ImageLoadCompletionBlock)completionBlock
{
  
  
  DFImageManagerRequest *request = [[DFImageManagerRequest alloc] initWithPhotoID:photoID
                                                                             size:size
                                                                      contentMode:contentMode
                                                                     deliveryMode:deliveryMode];
  // first check our cache
  UIImage *cachedImage = [self cachedImageForRequest:request];
  NSString *source;
  if (cachedImage) {
    source = @"memcache";
    if (completionBlock) completionBlock(cachedImage);
  }else if ([[DFImageStore sharedStore] canServeRequest:request]) {
    // opt for the cache first
    source = @"diskcache";
    [self serveRequestWithDiskCache:request completion:completionBlock];
  } else if ([self isLocalPhotoID:photoID]) {
    // otherwise see if we can get the photo locally
    source = @"dfasset";
    [self serveRequestFromPhotoStore:request completion:completionBlock];
  } else {
    // get the photo remotely
    source = @"remote";
    [self serveRequestFromNetwork:request completion:completionBlock];
  }
  DDLogVerbose(@"%@ routing %@ to %@: %@", self.class,
               completionBlock ? @"imageReq" : @"cacheReq",
               source,
               request);
}

- (void)startCachingImagesForPhotoIDs:(NSArray *)photoIDs
                           targetSize:(CGSize)size
                          contentMode:(DFImageRequestContentMode)contentMode
{
  for (NSNumber *photoID in photoIDs) {
    // simply get all of the images with a nil completion handler
    // the imageForID call should cache it as it does normally
    [self imageForID:photoID.longLongValue
                size:size
         contentMode:contentMode
        deliveryMode:DFImageRequestOptionsDeliveryModeHighQualityFormat
          completion:nil];
  }
}


#pragma mark - Logic for serving requests

- (BOOL)isLocalPhotoID:(DFPhotoIDType)photoID
{
  NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
  DFPhoto *photo = [DFPhotoStore photoWithPhotoID:photoID inContext:context];
  return (photo != nil);
}

- (void)serveRequestWithDiskCache:(DFImageManagerRequest *)request
                       completion:(ImageLoadCompletionBlock)completionBlock
{
  //if it matches the exact size of the thumbnail, just let the cache handle the request
  if (request.isDefaultThumbnail) {
    [[DFImageStore sharedStore] serveImageForRequest:request];
    return;
  }
  
  // otherwise, we may have to resize, schedule this deferred
  [self scheduleDeferredCompletion:completionBlock
                        forRequest:request
                     withLoadBlock:^{
                       return [[DFImageStore sharedStore] serveImageForRequest:request];
                     }];
}

- (void)serveRequestFromNetwork:(DFImageManagerRequest *)request
                completion:(ImageLoadCompletionBlock)completionBlock
{
  [self scheduleDeferredCompletion:completionBlock forRequest:request withLoadBlock:^UIImage *{
    UIImage __block *result = nil;
    dispatch_semaphore_t downloadSema = dispatch_semaphore_create(0);
    [[DFImageDownloadManager sharedManager]
     fetchImageDataForImageType:request.imageType
     andPhotoID:request.photoID
     completion:^(UIImage *image) {
       result = image;
       [[DFImageStore sharedStore] setImage:image
                                       type:request.imageType
                                      forID:request.photoID
                                 completion:nil];
       dispatch_semaphore_signal(downloadSema);
     }];
    
    dispatch_semaphore_wait(downloadSema, DISPATCH_TIME_FOREVER);
    return result;
  }];
}

- (void)cacheImage:(UIImage *)image forRequest:(DFImageManagerRequest *)request
{
  dispatch_semaphore_wait(self.imageRequestCacheSemaphore, DISPATCH_TIME_FOREVER);
  if (image) self.imageRequestCache[request] = image;
  dispatch_semaphore_signal(self.imageRequestCacheSemaphore);
}

- (UIImage *)cachedImageForRequest:(DFImageManagerRequest *)request
{
  UIImage *image;
  dispatch_semaphore_wait(self.imageRequestCacheSemaphore, DISPATCH_TIME_FOREVER);
  image = self.imageRequestCache[request];
  dispatch_semaphore_signal(self.imageRequestCacheSemaphore);
  return image;
}

- (void)clearCache
{
  dispatch_semaphore_wait(self.imageRequestCacheSemaphore, DISPATCH_TIME_FOREVER);
  _imageRequestCache = [NSMutableDictionary new];
  dispatch_semaphore_signal(self.imageRequestCacheSemaphore);
}


- (void)serveRequestFromPhotoStore:(DFImageManagerRequest *)request
                        completion:(ImageLoadCompletionBlock)completion
{
  [self
   scheduleDeferredCompletion:completion
   forRequest:request
   withLoadBlock:^UIImage *{
     NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
     DFPhoto *photo = [DFPhotoStore photoWithPhotoID:request.photoID inContext:context];
     UIImage *image = [photo.asset imageForRequest:request];
     return image;
   }];
}

#pragma mark - Deferred completion logic

- (void)scheduleDeferredCompletion:(ImageLoadCompletionBlock)completion
                        forRequest:(DFImageManagerRequest *)request
                     withLoadBlock:(UIImage *(^)(void))loadBlock
{
  BOOL callLoadBlock = NO;
  if (!completion) completion = ^(UIImage *image){}; // if we weren't handed a completion block, create an empty one
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);
  
  // figure out if there are similar requests ahead in the queue,
  // if there are none, we'll need to call the loadBlock at the end
  NSMutableSet *requestsForID = self.photoIDsToDeferredRequests[@(request.photoID)];
  NSArray *similarRequests = [self.class requestsLike:request inArray:requestsForID.allObjects];
  if (similarRequests.count == 0) callLoadBlock = YES;
  
  // keep track of this request in photoIDstoDeferredRequests
  if (!requestsForID) requestsForID = [NSMutableSet new];
  [requestsForID addObject:request];
  self.photoIDsToDeferredRequests[@(request.photoID)] = requestsForID;
  
  // then add the deferred completion handler to our list deferredCompletionBlocks
  NSMutableArray *deferredForRequest = self.deferredCompletionBlocks[request];
  if (!deferredForRequest) {
    deferredForRequest = [[NSMutableArray alloc] init];
    self.deferredCompletionBlocks[request] = deferredForRequest;
  }
  
  [deferredForRequest addObject:[completion copy]];
  dispatch_semaphore_signal(self.deferredCompletionSchedulerSemaphore);
  
  // call the load block, cache the image and execute the deferred completion handlers
  dispatch_queue_t queue = self.imageRequestQueue;
  if (!completion) queue = self.cacheRequestQueue;
  if (callLoadBlock) dispatch_async(self.imageRequestQueue, ^{
    UIImage *image = loadBlock();
    [self cacheImage:image forRequest:request];
    [self executeDeferredCompletionsWithImage:image forRequestsLike:request];
  });
}

- (void)executeDeferredCompletionsWithImage:(UIImage *)image forRequestsLike:(DFImageManagerRequest *)request
{
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);

  NSMutableSet *requestsForID = self.photoIDsToDeferredRequests[@(request.photoID)];
  NSMutableSet *executedRequests = [NSMutableSet new];
  //DDLogVerbose(@"executeDeferred begin requestsLike:%@ photoIDsToDeferredRequests:%@ requestsForID:%@", request, self.photoIDsToDeferredRequests, requestsForID);
  for (DFImageManagerRequest *otherRequest in [self.class requestsLike:request inArray:requestsForID.allObjects]) {
    [executedRequests addObject:otherRequest];
    NSMutableArray *deferredHandlers = self.deferredCompletionBlocks[request];
    //DDLogVerbose(@"request:%@ deferred:%@", otherRequest, deferredHandlers);
    NSMutableArray *executedHandlers = [NSMutableArray new];
    for (ImageLoadCompletionBlock completion in deferredHandlers) {
      completion(image);
      [executedHandlers addObject:completion];
    }
    [deferredHandlers removeObjectsInArray:executedHandlers];
  }
  [requestsForID minusSet:executedRequests];
  
  //DDLogVerbose(@"executeDeferred end photoIDsToDeferredRequests:%@ requestsForID:%@", self.photoIDsToDeferredRequests, requestsForID);
  dispatch_semaphore_signal(self.deferredCompletionSchedulerSemaphore);
}

+ (NSArray *)requestsLike:(DFImageManagerRequest *)request inArray:(NSArray *)array
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFImageManagerRequest *otherRequest in array) {
    if (CGSizeEqualToSize(otherRequest.size, request.size)) {
      [result addObject:otherRequest];
    }
  }
  return result;
}



@end
