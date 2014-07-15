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
NSString *const DFNearbyFriendsNotificationExpandedMessageKey = @"DFNearbyFriendsNotificationExpandedMessageKey";
NSTimeInterval const DFNearbyFriendsMinFetchInterval = 2.0;

@interface DFNearbyFriendsManager ()

@property (nonatomic, retain) DFNearbyFriendsAdapter *nearbyFriendsAdapter;
@property (nonatomic, retain) DFPeanutMessageResponse *lastResponse;
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
  self.isUpdatingNearbyFriends = YES;
  [self.nearbyFriendsAdapter
   fetchNearbyFriendsMessageForLocation:[[DFBackgroundLocationManager
                                          sharedBackgroundLocationManager] lastLocation]
   completionBlock:^(DFPeanutMessageResponse *response, NSError *error) {
     self.isUpdatingNearbyFriends = NO;
     if (!error) {
       DDLogInfo(@"%@ updated nearby friends message. newMessage:%@ oldMessage:%@",
                 [[self class] description], response.message, self.lastResponse.message);
       if ([self.lastResponse.message isEqualToString:response.message]) return;
       self.lastResponse = response;
       [[NSNotificationCenter defaultCenter]
        postMainThreadNotificationName:DFNearbyFriendsMessageUpdatedNotificationName
        object:self
        userInfo:@{
                   DFNearbyFriendsNotificationMessageKey: response.message,
                   DFNearbyFriendsNotificationExpandedMessageKey : response.expanded_message
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
  return self.lastResponse.message;
}

- (NSString *)expandedNearbyFriendsMessage
{
  if (!self.lastFetchDate) {
    [self updateNearbyFriendsMessage];
  }
  
  return self.lastResponse.expanded_message;
}


- (DFNearbyFriendsAdapter *)nearbyFriendsAdapter
{
  if (!_nearbyFriendsAdapter) {
    _nearbyFriendsAdapter = [[DFNearbyFriendsAdapter alloc] init];
  }
  
  return _nearbyFriendsAdapter;
}

@end
