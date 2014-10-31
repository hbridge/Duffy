//
//  DFImageManager.m
//  Strand
//
//  Created by Henry Bridge on 10/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageManager.h"
#import "DFPhotoAsset.h"
#import "DFImageDiskCache.h"
#import "DFImageDownloadManager.h"
#import "DFPhotoStore.h"
#import "DFPhotoResizer.h"
#import "UIDevice+DFHelpers.h"
#import <Photos/Photos.h>
#import "DFPHAsset.h"

@interface DFImageManager()

@property (readonly, atomic, retain) NSMutableDictionary *deferredCompletionBlocks;
@property (readonly, atomic, retain) NSMutableDictionary *photoIDsToDeferredRequests;
@property (atomic) dispatch_semaphore_t deferredCompletionSchedulerSemaphore;
@property (readonly, atomic) dispatch_queue_t imageRequestQueue;
@property (readonly, atomic) dispatch_queue_t cacheRequestQueue;
@property (readonly, atomic, retain) NSMutableDictionary *imageRequestCache;
@property (atomic) dispatch_semaphore_t imageRequestCacheSemaphore;

@property (atomic, readonly, retain) NSMutableSet *cacheRequestsInFlight;
@property (atomic) dispatch_semaphore_t cacheRequestsInFlightSemaphore;
@property (nonatomic, retain) PHCachingImageManager *cacheImageManager;


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
    
    
    dispatch_queue_attr_t imageReqAttrs;
    dispatch_queue_attr_t cache_attrs;
    if ([UIDevice majorVersionNumber] >= 8) {
      imageReqAttrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT,
                                                              QOS_CLASS_DEFAULT,
                                                              0);
      cache_attrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                            QOS_CLASS_BACKGROUND,
                                                            0);
      _imageRequestQueue = dispatch_queue_create("ImageReqQueue", imageReqAttrs);
      _cacheRequestQueue = dispatch_queue_create("ImageCacheReqQueue", cache_attrs);
    } else {
      _imageRequestQueue = dispatch_queue_create("ImageReqQueue", DISPATCH_QUEUE_CONCURRENT);
      dispatch_set_target_queue(_imageRequestQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
      _cacheRequestQueue = dispatch_queue_create("ImageCacheReqQueue", DISPATCH_QUEUE_SERIAL);
      dispatch_set_target_queue(_cacheRequestQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    }
    
    // setup the cache
    _imageRequestCache = [NSMutableDictionary new];
    _imageRequestCacheSemaphore = dispatch_semaphore_create(1);
    
    _cacheRequestsInFlight = [NSMutableSet new];
    _cacheRequestsInFlightSemaphore = dispatch_semaphore_create(1);

    _cacheImageManager = [[PHCachingImageManager alloc] init];
    
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
  if (CGSizeEqualToSize(size, CGSizeZero)) {
    if (completionBlock) completionBlock(nil);
    return;
  }
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
  } else if ([[DFImageDiskCache sharedStore] canServeRequest:request]) {
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
//  DDLogVerbose(@"%@ routing %@ to %@: %@", self.class,
//               completionBlock ? @"imageReq" : @"cacheReq",
//               source,
//               request);
}

- (void)startCachingImagesForPhotoIDs:(NSArray *)photoIDs
                           targetSize:(CGSize)size
                          contentMode:(DFImageRequestContentMode)contentMode
{
  NSMutableArray *idsNotInDiskCache = [NSMutableArray new];
  DFImageManagerRequest *templateRequest = [[DFImageManagerRequest alloc] initWithPhotoID:0
                                                                                     size:size
                                                                              contentMode:contentMode
                                                                             deliveryMode:DFImageRequestOptionsDeliveryModeHighQualityFormat];
  for (NSNumber *photoID in photoIDs) {
    // first see what we can get in mem or disk cache
    DFImageManagerRequest *request = [templateRequest copyWithPhotoID:photoID.longLongValue];
    
    if ([self checkAndSetCacheRequestInFlight:request]) {
      //DDLogVerbose(@"dupe cache request, ignoring");
     continue; //we're already caching this, continue
    }
    if ([self cachedImageForRequest:request]) {
      // we already have this in the cache or it's in progress, do nothing
      [self removeCacheRequestInFlight:request];
      continue;
    } else if ([[DFImageDiskCache sharedStore] canServeRequest:request]) {
      // if we can cache from the disk store, load the images from there
      dispatch_async(self.cacheRequestQueue, ^{
        UIImage *image = [[DFImageDiskCache sharedStore] serveImageForRequest:request];
        [self cacheImage:image forRequest:request];
      });
    } else {
      [idsNotInDiskCache addObject:photoID];
    }
  }
  
  [self cacheIDsNotInDiskCache:idsNotInDiskCache templateRequest:templateRequest];
}

- (BOOL)checkAndSetCacheRequestInFlight:(DFImageManagerRequest *)request
{
  BOOL result = NO;
  dispatch_semaphore_wait(self.cacheRequestsInFlightSemaphore, DISPATCH_TIME_FOREVER);
  if ([self.cacheRequestsInFlight containsObject:request]) result = YES;
  else ([self.cacheRequestsInFlight addObject:request]);
  dispatch_semaphore_signal(self.cacheRequestsInFlightSemaphore);
  return result;
}

- (void)removeCacheRequestInFlight:(DFImageManagerRequest *)request
{
  dispatch_semaphore_wait(self.cacheRequestsInFlightSemaphore, DISPATCH_TIME_FOREVER);
  [self.cacheRequestsInFlight removeObject:request];
  dispatch_semaphore_signal(self.cacheRequestsInFlightSemaphore);
}

- (void)cacheIDsNotInDiskCache:(NSArray *)idsNotInDiskCache
               templateRequest:(DFImageManagerRequest *)templateRequest
{
  if (idsNotInDiskCache.count > 0) {
    dispatch_async(self.cacheRequestQueue, ^{
      // see which photos we have locally, download the rest
      NSMutableArray *unfulfilledLocally = [idsNotInDiskCache mutableCopy];
      NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
      NSDictionary *localPhotosByID = [DFPhotoStore photosWithPhotoIDs:idsNotInDiskCache inContext:context];
      for (DFPhoto *photo in localPhotosByID.allValues) {
        DFImageManagerRequest *request = [templateRequest copyWithPhotoID:photo.photoID];
        UIImage __block *image;
        if ([[photo.asset class] isSubclassOfClass:[DFPHAsset class]]) {
          DFPHAsset *dfphAsset = (DFPHAsset *)photo.asset;
          [self.cacheImageManager requestImageForAsset:dfphAsset.asset
                                            targetSize:request.size
                                           contentMode:request.contentMode == DFImageRequestContentModeAspectFill ? PHImageContentModeAspectFill : PHImageContentModeAspectFit
                                               options:[DFPHAsset highQualityImageRequestOptions]
                                         resultHandler:^(UIImage *result, NSDictionary *info) {
                                           image = result;
                                         }];
        } else {
          image = [photo.asset imageForRequest:request];
        }
        
        [self cacheImage:image forRequest:request];
        if (image) {
          [unfulfilledLocally removeObject:@(photo.photoID)];
        }
      }
      
      for (NSNumber *unfulfilledID in unfulfilledLocally) {
        DFImageManagerRequest *request = [templateRequest copyWithPhotoID:unfulfilledID.longLongValue];
        [self serveRequestFromNetwork:request completion:nil];
      }
      
      //DDLogVerbose(@"cached %@ from photoStore, %@ from network.", @(localPhotosByID.count), @(unfulfilledLocally.count));
      
    });
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
  [self scheduleDeferredCompletion:completionBlock
                        forRequest:request
                     withLoadBlock:^{
                       return [[DFImageDiskCache sharedStore] serveImageForRequest:request];
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
       [[DFImageDiskCache sharedStore] setImage:image
                                       type:request.imageType
                                      forID:request.photoID
                                 completion:nil];
       dispatch_semaphore_signal(downloadSema);
     }];
    
    dispatch_semaphore_wait(downloadSema, DISPATCH_TIME_FOREVER);
    return result;
  }];
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

#pragma mark - Cache Management

- (void)cacheImage:(UIImage *)image forRequest:(DFImageManagerRequest *)request
{
  dispatch_semaphore_wait(self.imageRequestCacheSemaphore, DISPATCH_TIME_FOREVER);
  if (image) {
    // normalize the deliveryType since it doesn't matter for cache
    DFImageManagerRequest *cacheRequest = [request
                                           copyWithDeliveryMode:DFImageRequestOptionsDeliveryModeFastFormat];
    self.imageRequestCache[cacheRequest] = image;
  }
  dispatch_semaphore_signal(self.imageRequestCacheSemaphore);
  [self removeCacheRequestInFlight:request];
}

- (UIImage *)cachedImageForRequest:(DFImageManagerRequest *)request
{
  UIImage *image;
  // normalize the deliveryType since it doesn't matter for cache
  DFImageManagerRequest *cacheRequest = [request
                                         copyWithDeliveryMode:DFImageRequestOptionsDeliveryModeFastFormat];
  dispatch_semaphore_wait(self.imageRequestCacheSemaphore, DISPATCH_TIME_FOREVER);
  image = self.imageRequestCache[cacheRequest];
  dispatch_semaphore_signal(self.imageRequestCacheSemaphore);
  return image;
}

- (void)clearCache
{
  dispatch_semaphore_wait(self.imageRequestCacheSemaphore, DISPATCH_TIME_FOREVER);
  DDLogInfo(@"%@ clearing cache", self.class);
  _imageRequestCache = [NSMutableDictionary new];
  dispatch_semaphore_signal(self.imageRequestCacheSemaphore);
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
  NSMutableSet *requestsForID = self.photoIDsToDeferredRequests[@(request.photoID)];
  NSArray *similarRequests = [self.class requestsLike:request inArray:requestsForID.allObjects];
  if (similarRequests.count == 0) callLoadBlock = YES;
  //DDLogVerbose(@"%@ request: %@ has %d similarRequests ahead in queue.", self.class, request, (int)similarRequests.count);
  
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
  
  if (completion) [deferredForRequest addObject:completion];
  dispatch_semaphore_signal(self.deferredCompletionSchedulerSemaphore);

  if (callLoadBlock) {
    // call the load block, cache the image and execute the deferred completion handlers
    dispatch_queue_t queue = self.imageRequestQueue;
    if (!completion) {
      queue = self.cacheRequestQueue;
    }
    dispatch_async(queue, ^{
      UIImage *image = loadBlock();
      //DDLogVerbose(@"loadBlock for request:%@ image:%@", request, image);
      [self cacheImage:image forRequest:request];
      [self executeDeferredCompletionsWithImage:image forRequestsLike:request];
    });
  }
}

- (void)executeDeferredCompletionsWithImage:(UIImage *)image forRequestsLike:(DFImageManagerRequest *)request
{
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);

  NSMutableSet *requestsForID = self.photoIDsToDeferredRequests[@(request.photoID)];
  NSMutableSet *executedRequests = [NSMutableSet new];
  //DDLogVerbose(@"executeDeferred begin requestsFor:%d photoIDsToDeferredRequests:%@ requestsForID:%@", (int)request.photoID, self.photoIDsToDeferredRequests, requestsForID);
  NSArray *similarRequests = [self.class requestsLike:request inArray:requestsForID.allObjects];
  for (DFImageManagerRequest *similarRequest in similarRequests) {
    NSMutableArray *deferredHandlers = self.deferredCompletionBlocks[similarRequest];
    NSMutableArray *executedHandlers = [NSMutableArray new];
    for (ImageLoadCompletionBlock completion in deferredHandlers) {
      //DDLogVerbose(@"executing deferred completion for %@", similarRequest);
      completion(image);
      [executedHandlers addObject:completion];
    }
    [deferredHandlers removeObjectsInArray:executedHandlers];
    [executedRequests addObject:similarRequest];
  }
  [requestsForID minusSet:executedRequests];
  
  //DDLogVerbose(@"executeDeferred end requestsFor:%d photoIDsToDeferredRequests:%@ requestsForID:%@", (int)request.photoID, self.photoIDsToDeferredRequests, requestsForID);
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
