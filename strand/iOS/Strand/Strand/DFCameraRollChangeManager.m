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

- (void)checkForNewCameraRollPhotosWithCompletion:(void (^)(UIBackgroundFetchResult result))completion
{
  NSDate *lastDateRecorded = [DFDefaultsStore lastDateForAction:DFUserActionTakeExternalPhoto];
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
         if (completion)
           completion(UIBackgroundFetchResultNewData);
       } failure:^(NSError *error) {
         if (completion)
           completion(UIBackgroundFetchResultNewData);
       }];
    } else {
      DDLogInfo(@"%@ no new camera roll photos detected.", [self.class description]);
      if (completion)
        completion(UIBackgroundFetchResultNoData);
    }
  } promptUserIfNecessary:NO];
}

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) {
    _userAdapter = [[DFUserPeanutAdapter alloc] init];
  }
  
  return _userAdapter;
}

@end
