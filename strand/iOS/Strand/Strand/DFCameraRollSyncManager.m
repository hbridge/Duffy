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


@interface DFCameraRollSyncManager()

@property (nonatomic, retain) NSOperationQueue *syncOperationQueue;

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
    }
    return self;
}

- (void)sync
{
  [self syncAroundDate:nil];
}

- (void)syncAroundDate:(NSDate *)date
{
  DDLogInfo(@"Camera roll sync requested. %d sync operations ahead in queue.",
            (unsigned int)self.syncOperationQueue.operationCount);
  DFCameraRollSyncOperation *syncOperation;
  
  if ([UIDevice majorVersionNumber] >= 8) {
    syncOperation = [[DFIOS8CameraRollSyncOperation alloc] init];
    syncOperation.qualityOfService = NSOperationQualityOfServiceBackground;
  } else {
    syncOperation = [[DFIOS7CameraRollSyncOperation alloc] init];
    syncOperation.threadPriority = 0.2; //low, 0.5 is default
  }
  
  if (date) {
    DDLogVerbose(@"Sync targeting date: %@", date);
    syncOperation.targetDate = date;
  }
  
  [self.syncOperationQueue addOperation:syncOperation];
}

- (BOOL)isSyncInProgress
{
  return (self.syncOperationQueue.operationCount > 0);
}

- (void)cancelSyncOperations
{
  DDLogVerbose(@"Canceling all camera roll sync operations");
  [self.syncOperationQueue cancelAllOperations];
}




@end
