//
//  DFCameraRollSyncController.m
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollSyncManager.h"

#import "UIDevice+DFHelpers.h"

#import "DFCameraRollSyncOperation.h"
#import "DFIOS7CameraRollSyncOperation.h"
#import "DFIOS8CameraRollSyncOperation.h"
#import "DFDeletedPhotosSyncOperation.h"
#import "DFPeanutFeedDataManager.h"
#import "DFFaceDetectionSyncOperation.h"

@interface DFCameraRollSyncManager()

@property (nonatomic, retain) NSOperationQueue *syncOperationQueue;
@property (nonatomic) BOOL shouldRunDeleteSync;
@end

@implementation DFCameraRollSyncManager

static DFCameraRollSyncManager *defaultSyncController;

+ (DFCameraRollSyncManager *)sharedManager {
  if (!defaultSyncController) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      defaultSyncController = [[super allocWithZone:nil] init];
    });
  }
  return defaultSyncController;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
}

- (id)init
{
    self = [super init];
    if (self) {
      self.syncOperationQueue = [[NSOperationQueue alloc] init];
      self.syncOperationQueue.maxConcurrentOperationCount = 1;
      [self observeNotifications];
    }
    return self;
}


- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(deletedPhotoSync)
                                               name:DFStrandNewPrivatePhotosDataNotificationName
                                             object:nil];
}

/*
 * This is called when we come into the app and there now could be photos missing from our camera roll.
 * Maybe the user left the app and deleted something.
 * So run the deleted photo sync code.  But, we also might not have private data loaded up yet.  If thats the case
 * say that things haven't run yet and it should, and the listener should kick it off
 */
- (void)deletedPhotoSync
{
  DDLogVerbose(@"Starting deleted photo sync");
  
  if ([[DFPeanutFeedDataManager sharedManager] hasPrivateStrandData]) {
    DFDeletedPhotosSyncOperation *operation = [DFDeletedPhotosSyncOperation new];
    operation.queuePriority = NSOperationQueuePriorityLow;
    operation.threadPriority = 0.1; // very low, .5 is default
    [self.syncOperationQueue addOperation:operation];
    self.shouldRunDeleteSync = NO;
  } else {
    self.shouldRunDeleteSync = YES;
  }
}

- (void)facesSync
{
  DFFaceDetectionSyncOperation *operation = [DFFaceDetectionSyncOperation new];
  operation.queuePriority = NSOperationQueuePriorityLow;
  if ([UIDevice majorVersionNumber] >= 8) {
    operation.qualityOfService = NSOperationQualityOfServiceBackground;
  } else {
    operation.threadPriority = 0.2; //low, 0.5 is default
  }

  [self.syncOperationQueue addOperation:operation];
}

- (void)sync
{
  [self syncAroundDate:nil withCompletionBlock:nil];
  [self facesSync];
}

- (void)syncAroundDate:(NSDate *)date withCompletionBlock:(DFCameraRollSyncCompletionBlock)completionBlock
{
  DDLogInfo(@"Camera roll sync requested. %d sync operations ahead in queue.",
            (unsigned int)self.syncOperationQueue.operationCount);
  DFCameraRollSyncOperation *syncOperation;
  
  if ([UIDevice majorVersionNumber] >= 8) {
    syncOperation = [[DFIOS8CameraRollSyncOperation alloc] init];
    if (date) {
      syncOperation.qualityOfService = NSOperationQualityOfServiceUserInitiated;
    } else {
      syncOperation.qualityOfService = NSOperationQualityOfServiceBackground;
    }
  } else {
    syncOperation = [[DFIOS7CameraRollSyncOperation alloc] init];
    if (date) {
      syncOperation.threadPriority = 0.5; //0.5 is default
    } else {
      syncOperation.threadPriority = 0.2; //low, 0.5 is default
    }
  }
  
  if (date) {
    DDLogInfo(@"Sync targeting date: %@", date);
    syncOperation.targetDate = date;
  }
  
  syncOperation.completionBlockWithChanges = completionBlock;
  
  [self.syncOperationQueue addOperation:syncOperation];
}

- (BOOL)isSyncInProgress
{
  return (self.syncOperationQueue.operationCount > 0);
}

- (void)cancelSyncOperations
{
  DDLogInfo(@"Canceling all camera roll sync operations");
  [self.syncOperationQueue cancelAllOperations];
}




@end
