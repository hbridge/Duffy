//
//  DFUserInfoManager.m
//  Strand
//
//  Created by Henry Bridge on 8/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUserInfoManager.h"
#import "DFUserPeanutAdapter.h"


@interface DFUserInfoManager()

@property (readonly, nonatomic, retain) DFUserPeanutAdapter *userAdapter;

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


- (void)setFirstTimeSyncComplete
{
  DFPeanutUserObject *currentUserPeanutObject = [DFPeanutUserObject new];
  currentUserPeanutObject.id = [[DFUser currentUser] userID];
  [self.userAdapter performRequest:RKRequestMethodGET
                    withPeanutUser:currentUserPeanutObject
                           success:^(DFPeanutUserObject *user) {
                             user.first_run_sync_complete = @(YES);
                             [self.userAdapter performRequest:RKRequestMethodPATCH
                                               withPeanutUser:user
                                                      success:^(DFPeanutUserObject *user) {
                                                        DDLogVerbose(@"%@: Successfully set first_run_sync_complete for user %llu", self.class, user.id);
                                                      } failure:^(NSError *error) {
                                                        DDLogError(@"%@: Error in PATCH for user info with id %llu.  Error: %@", self.class, currentUserPeanutObject.id, error);
                                                      }];
                             
                           } failure:^(NSError *error) {
                             DDLogError(@"%@: Error in GET for user info with id %llu.  Error: %@", self.class, currentUserPeanutObject.id, error);
                           }];
}

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) {
    _userAdapter = [[DFUserPeanutAdapter alloc] init];
  }
  return _userAdapter;
}

@end
