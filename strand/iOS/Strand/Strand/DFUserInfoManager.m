//
//  DFUserInfoManager.m
//  Strand
//
//  Created by Henry Bridge on 8/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUserInfoManager.h"
#import "DFPeanutUserAdapter.h"


@interface DFUserInfoManager()

@property (readonly, nonatomic, retain) DFPeanutUserAdapter *userAdapter;

@end


@implementation DFUserInfoManager

@synthesize userAdapter = _userAdapter;

// We want the upload controller to be a singleton
static DFUserInfoManager *defaultManager;
+ (DFUserInfoManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
}

- (id)init
{
  self = [super init];
  if (self) {
  }
  return self;
}


- (void)setFirstTimeSyncCount:(NSNumber *)photoCount
{
  DFPeanutUserObject *currentUserPeanutObject = [DFPeanutUserObject new];
  currentUserPeanutObject.id = [[DFUser currentUser] userID];
  [self.userAdapter performRequest:RKRequestMethodGET
                    withPeanutUser:currentUserPeanutObject
                           success:^(DFPeanutUserObject *user) {
                             // If our first_run_sync_state is 0, that means we haven't told the server we're good yet
                             //   So update it to a state of 1, and send that back to the server
                             if (!user.first_run_sync_count) {
                               user.first_run_sync_count = photoCount;
                               [self.userAdapter performRequest:RKRequestMethodPATCH
                                                 withPeanutUser:user
                                                        success:^(DFPeanutUserObject *user) {
                                                          DDLogVerbose(@"%@: Successfully set first_run_sync_complete for user %llu", self.class, user.id);
                                                        } failure:^(NSError *error) {
                                                          DDLogError(@"%@: Error in PATCH for user info with id %llu.  Error: %@", self.class, currentUserPeanutObject.id, error);
                                                        }];
                             }
                           } failure:^(NSError *error) {
                             DDLogError(@"%@: Error in GET for user info with id %llu.  Error: %@", self.class, currentUserPeanutObject.id, error);
                           }];
}


- (void)setLastPhotoTimestamp:(NSDate *)timestamp
{
  DFPeanutUserObject *user = [DFPeanutUserObject new];
  user.last_photo_timestamp = timestamp;
  user.last_photo_update_timestamp = [[NSDate alloc] init];
  [self updateCurrentUserToUser:user];
};

- (void)setLastCheckinTimestamp:(NSDate *)timestamp
{
  DFPeanutUserObject *user = [DFPeanutUserObject new];
  user.last_checkin_timestamp = timestamp;
  [self updateCurrentUserToUser:user];
}

- (void)setLastNotifsOpenedTimestamp:(NSDate *)date
{
  DFPeanutUserObject *user = [DFPeanutUserObject new];
  user.last_actions_list_request_timestamp = date;
  [self updateCurrentUserToUser:user];
}

- (void)updateCurrentUserToUser:(DFPeanutUserObject *)user
{
   user.id = [[DFUser currentUser] userID];
  [self.userAdapter
   performRequest:RKRequestMethodPATCH
   withPeanutUser:user
   success:^(DFPeanutUserObject *user) {
     DDLogVerbose(@"%@: successfully set user to: %@", self.class, user);
   } failure:^(NSError *error) {
     DDLogError(@"%@: Error in PATCH for user info with id %llu.  Error: %@", self.class, user.id, error);
   }];

}

- (DFPeanutUserAdapter *)userAdapter
{
  if (!_userAdapter) {
    _userAdapter = [[DFPeanutUserAdapter alloc] init];
  }
  return _userAdapter;
}

@end
