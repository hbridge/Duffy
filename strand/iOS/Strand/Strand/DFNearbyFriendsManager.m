//
//  DFNearbyFriendsManager.m
//  Strand
//
//  Created by Henry Bridge on 7/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNearbyFriendsManager.h"
#import "DFNearbyFriendsAdapter.h"
#import "DFBackgroundLocationManager.h"
#import "NSNotificationCenter+DFThreadingAddons.h"

NSString *const DFNearbyFriendsMessageUpdatedNotificationName = @"DFNearbyFriendsMessageUpdatedNotificationName";
NSString *const DFNearbyFriendsNotificationMessageKey = @"DFNearbyFriendsNotificationMessageKey";
NSTimeInterval const DFNearbyFriendsMinFetchInterval = 2.0;

@interface DFNearbyFriendsManager ()

@property (nonatomic, retain) DFNearbyFriendsAdapter *nearbyFriendsAdapter;
@property (nonatomic, retain) NSString *lastMessage;
@property (nonatomic, retain) NSDate *lastFetchDate;
@property (atomic) BOOL isUpdatingNearbyFriends;

@end

@implementation DFNearbyFriendsManager

static DFNearbyFriendsManager *defaultManager;

+ (DFNearbyFriendsManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self updateNearbyFriendsMessage];
    
  }
  return self;
}

- (void)updateNearbyFriendsMessage
{
  if (self.isUpdatingNearbyFriends) return;
  [self.nearbyFriendsAdapter
   fetchNearbyFriendsMessageForLocation:[[DFBackgroundLocationManager
                                          sharedBackgroundLocationManager] lastLocation]
   completionBlock:^(DFPeanutMessageResponse *response, NSError *error) {
     self.isUpdatingNearbyFriends = NO;
     if (!error) {
       DDLogInfo(@"%@ updated nearby friends message. newMessage:%@ oldMessage:%@",
                 [[self class] description], response.message, self.lastMessage);
       if ([self.lastMessage isEqualToString:response.message]) return;
       self.lastMessage = response.message;
       [[NSNotificationCenter defaultCenter]
        postMainThreadNotificationName:DFNearbyFriendsMessageUpdatedNotificationName
        object:self
        userInfo:@{
                   DFNearbyFriendsNotificationMessageKey: response.message
                   }];
       
     } else {
       DDLogWarn(@"%@ got an error for message fetch: %@", [[self class] description], error);
     }
   }];
}

- (NSString *)nearbyFriendsMessage
{
  if (!self.lastFetchDate ||
      [[NSDate date] timeIntervalSinceDate:self.lastFetchDate] > DFNearbyFriendsMinFetchInterval) {
    [self updateNearbyFriendsMessage];
  }
  return self.lastMessage;
}


- (DFNearbyFriendsAdapter *)nearbyFriendsAdapter
{
  if (!_nearbyFriendsAdapter) {
    _nearbyFriendsAdapter = [[DFNearbyFriendsAdapter alloc] init];
  }
  
  return _nearbyFriendsAdapter;
}

@end
