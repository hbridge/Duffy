//
//  DFCameraRollChangeManager.m
//  Strand
//
//  Created by Henry Bridge on 7/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCameraRollChangeManager.h"
#import "DFPhotoStore.h"
#import "DFDefaultsStore.h"
#import "DFUserPeanutAdapter.h"

@interface DFCameraRollChangeManager()

@property (nonatomic, retain) DFUserPeanutAdapter *userAdapter;

@end

@implementation DFCameraRollChangeManager

static DFCameraRollChangeManager *defaultManager;
+ (DFCameraRollChangeManager *)sharedManager
{
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
}

- (UIBackgroundFetchResult)backgroundChangeScan
{
  NSDate *lastDateRecorded = [DFDefaultsStore lastDateForAction:DFUserActionTakeExternalPhoto];
  UIBackgroundFetchResult __block result;
  dispatch_semaphore_t completion_semaphore = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    [[DFPhotoStore sharedStore] fetchMostRecentSavedPhotoDate:^(NSDate *lastPhotoDate) {
      if (lastPhotoDate && ![lastDateRecorded isEqualToDate:lastPhotoDate]) {
        DDLogInfo(@"%@ new camera roll photo detected. old most recent:%@ new most recent:%@",
                  [self.class description], lastDateRecorded, lastPhotoDate);
        DFPeanutUserObject *peanutUser = [[DFPeanutUserObject alloc] init];
        peanutUser.id = [[DFUser currentUser] userID];
        peanutUser.last_photo_timestamp = lastPhotoDate;
        [self.userAdapter
         performRequest:RKRequestMethodPUT
         withPeanutUser:peanutUser
         success:^(DFPeanutUserObject *user) {
           [DFDefaultsStore setLastDate:lastPhotoDate forAction:DFUserActionTakeExternalPhoto];
           result = UIBackgroundFetchResultNewData;
           dispatch_semaphore_signal(completion_semaphore);
         } failure:^(NSError *error) {
           result = UIBackgroundFetchResultFailed;
           dispatch_semaphore_signal(completion_semaphore);
         }];
      } else {
        DDLogInfo(@"%@ no new camera roll photos detected.", [self.class description]);
        result = UIBackgroundFetchResultNoData;
        dispatch_semaphore_signal(completion_semaphore);
      }
    } promptUserIfNecessary:NO];
  });
  
  dispatch_semaphore_wait(completion_semaphore, dispatch_time(DISPATCH_TIME_NOW, 28 * NSEC_PER_SEC));
  return result;
}

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) {
    _userAdapter = [[DFUserPeanutAdapter alloc] init];
  }
  
  return _userAdapter;
}

@end
