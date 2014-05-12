//
//  DFUploadController2.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import "DFUploadQueue.h"
#import "DFUploadOperation.h"
#import "DFAnalytics.h"
#import "DFStatusBarNotificationManager.h"
#import "NSNotificationCenter+DFThreadingAddons.h"
#import "DFNotificationSharedConstants.h"
#import <RestKit/RestKit.h>
#import "DFLocationPinger.h"
#import "DFPeanutPhoto.h"

@interface DFUploadController()

@property (atomic, retain) DFUploadQueue *thumbnailsObjectIDQueue;
@property (atomic, retain) DFUploadQueue *fullImageObjectIDQueue;
@property (readonly, nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@property (atomic, retain) NSOperationQueue *syncOperationQueue;
@property (atomic, retain) NSOperationQueue *uploadOperationQueue;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundUpdateTask;

@property (nonatomic, retain) DFUploadSessionStats *currentSessionStats;

@end


@implementation DFUploadController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize currentSessionStats = _currentSessionStats;

static unsigned int MaxConcurrentUploads = 2;
static unsigned int MaxRetryCount = 5;
static unsigned int MaxThumbnailsPerRequest = 100;

// We want the upload controller to be a singleton
static DFUploadController *defaultUploadController;
+ (DFUploadController *)sharedUploadController {
    if (!defaultUploadController) {
        defaultUploadController = [[super allocWithZone:nil] init];
    }
    return defaultUploadController;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedUploadController];
}


- (id)init
{
    self = [super init];
    if (self) {
        self.thumbnailsObjectIDQueue = [[DFUploadQueue alloc] init];
        self.fullImageObjectIDQueue = [[DFUploadQueue alloc] init];
        // Setup operation queues
        self.syncOperationQueue = [[NSOperationQueue alloc] init];
        self.syncOperationQueue.maxConcurrentOperationCount = 1;
        self.uploadOperationQueue = [[NSOperationQueue alloc] init];
        self.uploadOperationQueue.maxConcurrentOperationCount = MaxConcurrentUploads;
        // setup battery monitoring
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundContextDidSave:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:nil];
    }
    return self;
}


#pragma mark - Public methods

- (void)uploadPhotos
{
    [self addPhotosIDsToQueue];
}

- (void)cancelUploads
{
    NSOperation *cancelOperation = [self cancelAllUploadsOperationWithIsError:NO silent:NO];
    cancelOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
    [self scheduleWithDispatchUploads:NO operation:cancelOperation];
}

- (BOOL)isUploadInProgress
{
    return self.thumbnailsObjectIDQueue.numObjectsIncomplete + self.fullImageObjectIDQueue.numObjectsIncomplete > 0;
}

#pragma mark - Upload scheduling

- (void)addPhotosIDsToQueue
{
    [self scheduleWithDispatchUploads:YES operation:[NSBlockOperation blockOperationWithBlock:^{
        DFPhotoCollection *photosWithThumbsToUpload =
            [DFPhotoStore photosWithThumbnailUploadStatus:NO fullUploadStatus:NO inContext:self.managedObjectContext];
        DFPhotoCollection *eligibleFullImagesToUpload =
            [DFPhotoStore photosWithThumbnailUploadStatus:YES fullUploadStatus:NO inContext:self.managedObjectContext];
        
//        DDLogVerbose(@"thumbnailsObjectIDQueue:%@ adding photos to \nthumbnails queue: %@ \nfullImageQueue: %@",
//                     self.thumbnailsObjectIDQueue.description, photosWithThumbsToUpload.description, eligibleFullImagesToUpload.description);
        
        [self.thumbnailsObjectIDQueue addObjectsFromArray:[photosWithThumbsToUpload objectIDsByDateAscending:NO]];
        [self.fullImageObjectIDQueue addObjectsFromArray:[eligibleFullImagesToUpload objectIDsByDateAscending:NO]];
        
//        DDLogVerbose(@"result thumbnailsObjectIDQueue: %@", self.thumbnailsObjectIDQueue.description);
    }]];
}

- (void)scheduleWithDispatchUploads:(BOOL)dispatchUploadsOnComplete operation:(NSOperation *)operation
{
    if (dispatchUploadsOnComplete) {
        operation.completionBlock = ^{
            [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
        };
    }
    [self.syncOperationQueue addOperation:operation];
}

- (NSOperation *)dispatchUploadsOperation
{
    return [NSBlockOperation blockOperationWithBlock:^{
        [self postStatusUpdate];
        DDLogVerbose(@"Dispatching uploads if required...");
        if (self.uploadOperationQueue.operationCount >= self.uploadOperationQueue.maxConcurrentOperationCount) {
            DDLogVerbose(@"Already maxed out on operations.");
            return;
        }
        
        if (![self isDeviceStateGoodForBackgroundUploads]) {
            DDLogInfo(@"Device is not in good state for uploads.  Not scheduling upload.");
            if (self.uploadOperationQueue.operationCount == 0) [self endBackgroundUpdateTask];
            return;
        }
        
        DFUploadOperation *uploadOperation = [[DFUploadOperation alloc] init];
        NSArray *nextThumbnailIDs = [self.thumbnailsObjectIDQueue takeNextObjects:MaxThumbnailsPerRequest];
        if (nextThumbnailIDs.count > 0) {
            uploadOperation.photoIDs = nextThumbnailIDs;
            uploadOperation.uploadOperationType = DFPhotoUploadOperationThumbnailData;
        } else {
            NSArray *nextFullImageIDs = [self.fullImageObjectIDQueue takeNextObjects:1];
            uploadOperation.photoIDs = nextFullImageIDs;
            uploadOperation.uploadOperationType = DFPhotoUploadOperationFullImageData;
        }
        
        if (uploadOperation.photoIDs.count > 0) {
            [self beginBackgroundUpdateTask];
            uploadOperation.completionOperationQueue = self.syncOperationQueue;
            uploadOperation.successBlock = [self uploadSuccessfullBlock];
            uploadOperation.failureBlock = [self uploadFailureBlock];
            [self.uploadOperationQueue addOperation:uploadOperation];
            if (self.uploadOperationQueue.operationCount < self.uploadOperationQueue.maxConcurrentOperationCount) {
                [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
            }
        } else {
            //there's nothing else to upload, check to see if everything's complete
            if (self.thumbnailsObjectIDQueue.numObjectsIncomplete + self.fullImageObjectIDQueue.numObjectsIncomplete == 0
                && self.thumbnailsObjectIDQueue.numObjectsComplete + self.fullImageObjectIDQueue.numObjectsIncomplete > 0) {
                [self scheduleWithDispatchUploads:NO operation:[self allUploadsCompleteOperation]];
            }
        }
    }];
}

- (BOOL)isDeviceStateGoodForBackgroundUploads
{
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    AFNetworkReachabilityStatus reachabilityStatus = [[[RKObjectManager sharedManager] HTTPClient] networkReachabilityStatus];
    
    // if we're in the background we may not want upload
    if (appState == UIApplicationStateBackground) {
        // if we're not on wifi don't upload
        if (reachabilityStatus != AFNetworkReachabilityStatusReachableViaWiFi) {
            return NO;
          DDLogInfo(@"Not on wifi. isDeviceStateGoodForBackgroundUploads:NO");
        }
        
        // if the battery is < 50% and it's not plugged in (or don't know) don't upload
        UIDeviceBatteryState batteryState = [[UIDevice currentDevice] batteryState];
        float batteryChargeLevel = [[UIDevice currentDevice] batteryLevel];
        if ((batteryState == UIDeviceBatteryStateUnplugged)
            && batteryChargeLevel < 0.05) {
          DDLogInfo(@"Battery state unplugged and charge level %.02f. isDeviceStateGoodForBackgroundUploads:NO", batteryChargeLevel);
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Upload operation response handlers

- (DFPhotoUploadOperationSuccessBlock)uploadSuccessfullBlock
{
    DFPhotoUploadOperationSuccessBlock successBlock = ^(NSDictionary *resultDictionary){
        NSArray *peanutPhotos = resultDictionary[DFUploadResultPeanutPhotos];
        if (peanutPhotos.count < 1) [NSException raise:@"DFUploadController upload result with no photos"
                                                format:@"Uploaded photos result contained no photos in the result array."];
        [self saveUploadedPhotosWithPeanutPhotos:peanutPhotos uploadOperationType:resultDictionary[DFUploadResultOperationType]];
        self.currentSessionStats.numConsecutiveRetries = 0;
        self.currentSessionStats.numBytesUploaded += [resultDictionary[DFUploadResultNumBytes] unsignedLongValue];
        [DFAnalytics logUploadEndedWithResult:DFAnalyticsValueResultSuccess
                                numPhotos:peanutPhotos.count
                     sessionAvgThroughputKBPS:self.currentSessionStats.throughPutKBPS];
        [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
    };
    return successBlock;
}

- (void)saveUploadedPhotosWithPeanutPhotos:(NSArray *)peanutPhotos uploadOperationType:(DFPhotoUploadOperationImageDataType)uploadType
{
    NSMutableDictionary *metadataChanges = [[NSMutableDictionary alloc] initWithCapacity:peanutPhotos.count];
    for (DFPeanutPhoto *peanutPhoto in peanutPhotos) {
        // Update the DFPhoto with info returned from server
        DFPhoto *photo = [peanutPhoto photoInContext:self.managedObjectContext];
        [self updatePhoto:photo withPeanutPhotos:peanutPhoto];
        
        // Mark the photo as complete in the queue and record changes
        metadataChanges[photo.objectID] = DFPhotoChangeTypeMetadata;
        
        if (uploadType == DFPhotoUploadOperationThumbnailData) {
            photo.upload157Date = [NSDate date];
            if (peanutPhoto.full_filename && ![peanutPhoto.full_filename isEqualToString:@""])
                DDLogWarn(@"Interesting: got non null full filename (%@) for photo we're just uploading thumbnail for.", peanutPhoto.full_filename);
            // Manage out upload queues
            [self.thumbnailsObjectIDQueue markObjectCompleted:photo.objectID];
            [self.fullImageObjectIDQueue addObjectsFromArray:@[photo.objectID]];
        } else if (uploadType == DFPhotoUploadOperationFullImageData) {
            photo.upload569Date = [NSDate date];
            [self.fullImageObjectIDQueue markObjectCompleted:photo.objectID];
        } else {
          [NSException raise:@"No DFPhotoUploadOperationImageDataType"
                      format:@"Upload completed without DFPhotoUploadOperationImageDataType"];
        }
    }
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFPhotoChangedNotificationName
                                                                  object:self
                                                                userInfo:metadataChanges];
}

- (void)updatePhoto:(DFPhoto *)photo withPeanutPhotos:(DFPeanutPhoto *)peanutPhoto
{
    photo.photoID = [peanutPhoto.id unsignedLongLongValue];
}

- (DFPhotoUploadOperationFailureBlock)uploadFailureBlock
{
    DFPhotoUploadOperationFailureBlock failureBlock = ^(NSDictionary *resultDict, BOOL isCancelled){
        if (isCancelled) return;
        
        NSError *error = resultDict[DFUploadResultErrorKey];
        DFPhotoUploadOperationImageDataType uploadType = resultDict[DFUploadResultOperationType];
        NSArray *peanutPhotos = resultDict[DFUploadResultPeanutPhotos];
        NSMutableArray *objectIDs = [[NSMutableArray alloc] initWithCapacity:peanutPhotos.count];
        for (DFPeanutPhoto *peanutPhoto in peanutPhotos) {
            NSManagedObjectID *objectID = [[peanutPhoto photoInContext:self.managedObjectContext] objectID];
            if (objectID == nil) [NSException raise:@"nil NSManagedObjectID" format:@"objectID in upload failureblock nil."];
            [objectIDs addObject:objectID];
        }
        
        DDLogVerbose(@"Upload failed for %lu objects", peanutPhotos.count);
        if ([self isErrorRetryable:error] && self.currentSessionStats.numConsecutiveRetries < MaxRetryCount) {
            DDLogVerbose(@"Error retryable.  Moving objects to back of queue.");
            if (uploadType == DFPhotoUploadOperationThumbnailData) {
                [self.thumbnailsObjectIDQueue moveInProgressObjectsBackToQueue:objectIDs];
            } else if (uploadType == DFPhotoUploadOperationFullImageData) {
                [self.fullImageObjectIDQueue moveInProgressObjectsBackToQueue:objectIDs];
            } else {
              [NSException raise:@"No DFPhotoUploadOperationImageDataType" format:@"Error retryable but no DFPhotoUploadOperationImageDataType"];
            }
            self.currentSessionStats.numConsecutiveRetries++;
            self.currentSessionStats.numTotalRetries++;
        } else {
          DDLogInfo(@"Retry count exceeded (%d/%d) or error not retryable. Cancelling uploads.  Error:%@",
                    self.currentSessionStats.numConsecutiveRetries, MaxRetryCount, error.description);
            [DFAnalytics logUploadRetryCountExceededWithCount:self.currentSessionStats.numConsecutiveRetries];
            NSOperation *cancelOperation = [self cancelAllUploadsOperationWithIsError:YES silent:NO];
            [cancelOperation start];
        }
        
        [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
    };
    return failureBlock;
}

- (BOOL)isErrorRetryable:(NSError *)error
{
    if (error.code == -1001 || // timeout
        error.code == -1021 || // request body stream exhausted
        error.code == -1005    // network connection was lost
        ){
        return YES;
    }
    
    return NO;
}

#pragma mark - End of uploads

- (NSOperation *)cancelAllUploadsOperationWithIsError:(BOOL)isError silent:(BOOL)isSilent
{
    return [NSBlockOperation blockOperationWithBlock:^{
        DDLogInfo(@"Cancelling all operations with isError:%@ isSilent%@",
                  isError ? @"true" : @"false",
                  isSilent ? @"true" : @"false");
        [self.thumbnailsObjectIDQueue removeAllObjects];
        [self.fullImageObjectIDQueue removeAllObjects];
        [self.uploadOperationQueue cancelAllOperations];
        _currentSessionStats = nil;
        
        if (!isSilent){
            if (isError) {
                [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateError
                                                                                            numRemaining:0
                                                                                                progress:0.0];
            } else {
                [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateCancelled
                                                                                            numRemaining:0
                                                                                                progress:0.0];
            }
            [DFAnalytics logUploadCancelledWithIsError:isError];
        }
        [self endBackgroundUpdateTask];
    }];
}

- (NSOperation *)allUploadsCompleteOperation
{
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        DDLogInfo(@"All uploads complete.");
        _currentSessionStats = nil;
        [self showBackgroundUploadCompleteNotif];
        [self endBackgroundUpdateTask];
        [self.thumbnailsObjectIDQueue clearCompleted];
        [self.fullImageObjectIDQueue clearCompleted];
    }];
    
    operation.queuePriority = NSOperationQueuePriorityHigh;
    return operation;
}

- (void)showBackgroundUploadCompleteNotif
{
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UILocalNotification *localNotif = [[UILocalNotification alloc] init];
        if (localNotif) {
            localNotif.alertBody = @"Ready to search your photos!";
            localNotif.alertAction = NSLocalizedString(@"Open", nil);
            localNotif.applicationIconBadgeNumber = 1;
            [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
        }
    });
}

#pragma mark - Misc helpers

- (void)postStatusUpdate
{
    DFUploadSessionStats *currentStats = [self currentSessionStats];
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFUploadStatusNotificationName
                                                                  object:self
                                                                userInfo:@{DFUploadStatusUpdateSessionUserInfoKey: currentStats}];
    
    if (currentStats.numThumbnailsRemaining > 0) {
        [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateThumbnailProgress
                                                                                    numRemaining:currentStats.numThumbnailsRemaining
                                                                                        progress:currentStats.thumbnailProgress];
    } else if (currentStats.numFullPhotosRemaining > 0) {
        [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateFullImageProgress
                                                                                    numRemaining:currentStats.numFullPhotosRemaining
                                                                                        progress:currentStats.fullPhotosProgress];
    } else if (currentStats.numThumbnailsUploaded > 0 || currentStats.numFullPhotosUploaded > 0){
        [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateComplete
                                                                                    numRemaining:0
                                                                                        progress:1.0];
    }
    
    DDLogInfo(@"\n%@", currentStats.description);
}

- (DFUploadSessionStats *)currentSessionStats
{
    if (!_currentSessionStats) {
        _currentSessionStats = [[DFUploadSessionStats alloc] init];
        _currentSessionStats.startDate = [NSDate date];
    }
    _currentSessionStats.numThumbnailsAccepted = self.thumbnailsObjectIDQueue.numTotalObjects;
    _currentSessionStats.numThumbnailsUploaded = self.thumbnailsObjectIDQueue.numObjectsComplete;
    _currentSessionStats.numFullPhotosAccepted = self.fullImageObjectIDQueue.numTotalObjects;
    _currentSessionStats.numFullPhotosUploaded = self.fullImageObjectIDQueue.numObjectsComplete;

    return _currentSessionStats;
}

#pragma mark - Core Data helpers


- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
  
  _managedObjectContext = [[DFPhotoStore sharedStore] createBackgroundManagedObjectContext];
  return _managedObjectContext;
}

- (void)saveContext
{
    NSError *error = nil;
    if(![self.managedObjectContext save:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [NSException raise:@"Could not save upload photo progress." format:@"Error: %@",[error localizedDescription]];
    }
}


/* Save notification handler for the background context */
- (void)backgroundContextDidSave:(NSNotification *)notification {
    /* merge in the changes to the main context */
    [self scheduleWithDispatchUploads:YES operation:[NSBlockOperation blockOperationWithBlock:^{
        [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
        [self uploadPhotos];
    }]];
}

# pragma mark - Background task helper

- (void) beginBackgroundUpdateTask
{
    if (self.backgroundUpdateTask != UIBackgroundTaskInvalid) {
        return;
    }
    
    [[DFLocationPinger sharedInstance] addObjectRequestingKeepAlive:self];
    if ([[DFLocationPinger sharedInstance] canMonitorLocation]) {
        [[DFLocationPinger sharedInstance] startPings];
    }
    self.backgroundUpdateTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        DDLogInfo(@"Background upload task about to expire.  Canceling uploads...");
        
        // By cancel will throw an exception on the main thread because it could block.  That's the behavior
        // we want here so we create a semaphore an wait on it.
        NSOperation *cancelOperation = [self cancelAllUploadsOperationWithIsError:NO silent:YES];
        cancelOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
        [self scheduleWithDispatchUploads:NO operation:cancelOperation];
        // the cancel operation ends the background task
    }];
}

- (void) endBackgroundUpdateTask
{
    DDLogInfo(@"Ending background update task.");
    [[DFLocationPinger sharedInstance] removeObjectRequestingKeepAlive:self];
    [[UIApplication sharedApplication] endBackgroundTask: self.backgroundUpdateTask];
    self.backgroundUpdateTask = UIBackgroundTaskInvalid;
}



@end
