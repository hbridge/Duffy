//
//  DFCameraRollSyncController.m
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollSyncController.h"
#import "DFCameraRollSyncOperation.h"


@interface DFCameraRollSyncController()

@property (nonatomic, retain) NSOperationQueue *syncOperationQueue;

@end

@implementation DFCameraRollSyncController

static DFCameraRollSyncController *defaultSyncController;

+ (DFCameraRollSyncController *)sharedSyncController {
  if (!defaultSyncController) {
    defaultSyncController = [[super allocWithZone:nil] init];
  }
  return defaultSyncController;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedSyncController];
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

- (void)asyncSyncToCameraRoll
{
    DDLogInfo(@"Camera roll sync requested. %d sync operations ahead in queue.",
              (unsigned int)self.syncOperationQueue.operationCount);
  DFCameraRollSyncOperation *syncOperation = [[DFCameraRollSyncOperation alloc] init];
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
