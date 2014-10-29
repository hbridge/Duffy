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
@property (readonly, atomic) dispatch_queue_t requestQueue;
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
    _requestQueue = dispatch_queue_create("ImageManagerReqQueue", attrs);
    _imageRequestCache = [NSMutableDictionary new];
    _imageRequestCacheSemaphore = dispatch_semaphore_create(1);
  }
  return self;
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
    completionBlock(cachedImage);
  }else if ([[DFImageStore sharedStore] canServeRequest:request]) {
    // opt for the cache first
    source = @"diskcache";
    [self serveRequestWithDiskCache:request completion:completionBlock];
  } else if ([self isLocalPhotoID:photoID]) {
    // otherwise see if we can get the photo locally
    source = @"local";
    [self serveRequestFromPhotoStore:request completion:completionBlock];
  } else {
    // get the photo remotely
    source = @"remote";
    [self serveRequestFromNetwork:request completion:completionBlock];
  }
  DDLogVerbose(@"%@ routing to %@: %@", self.class, source, request);
}

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
  self.imageRequestCache[request] = image;
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
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);
  
  // figure out if there are similar requests ahead in the queue,
  // if there are none, we'll need to call the loadBlock at the end
  NSMutableArray *requestsForID = self.photoIDsToDeferredRequests[@(request.photoID)];
  NSArray *similarRequests = [self.class requestsLike:request inArray:requestsForID];
  if (similarRequests.count == 0) callLoadBlock = YES;
  
  // keep track of this request in photoIDstoDeferredRequests
  if (!requestsForID) requestsForID = [NSMutableArray new];
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
  if (callLoadBlock) dispatch_async(self.requestQueue, ^{
    UIImage *image = loadBlock();
    [self cacheImage:image forRequest:request];
    [self executeDeferredCompletionsWithImage:image forRequestsLike:request];
  });
}

- (void)executeDeferredCompletionsWithImage:(UIImage *)image forRequestsLike:(DFImageManagerRequest *)request
{
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);
  NSMutableArray *requestsForID = self.photoIDsToDeferredRequests[@(request.photoID)];
  
  NSMutableArray *executedRequests = [NSMutableArray new];
  for (DFImageManagerRequest *otherRequest in [self.class requestsLike:request inArray:requestsForID]) {
    [executedRequests addObject:otherRequest];
    NSMutableArray *executedHandlers = [NSMutableArray new];
    NSMutableArray *deferredForRequest = self.deferredCompletionBlocks[request];
    for (ImageLoadCompletionBlock completion in deferredForRequest) {
      completion(image);
      [executedHandlers addObject:completion];
    }
    [deferredForRequest removeObjectsInArray:executedHandlers];
  }
  [requestsForID removeObjectsInArray:executedRequests];
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
