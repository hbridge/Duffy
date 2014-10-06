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
    defaultSyncController = [[super allocWithZone:nil] init];
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
    DDLogInfo(@"Camera roll sync requested. %d sync operations ahead in queue.",
              (unsigned int)self.syncOperationQueue.operationCount);
  DFCameraRollSyncOperation *syncOperation;
  
  if ([UIDevice majorVersionNumber] >= 8) {
    syncOperation = [[DFIOS8CameraRollSyncOperation alloc] init];
  } else {
    syncOperation = [[DFIOS7CameraRollSyncOperation alloc] init];
  }
  
  syncOperation.threadPriority = 0.2; //low, 0.5 is default
  [self.syncOperationQueue addOperation:syncOperation];
}

- (BOOL)isSyncInProgress
{
  return (self.syncOperationQueue.operationCount > 0);
}

- (void)cancelSyncOperations
{
  [self.syncOperationQueue cancelAllOperations];
}




@end
