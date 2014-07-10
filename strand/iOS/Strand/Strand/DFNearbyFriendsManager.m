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

@interface DFNearbyFriendsManager ()

@property (nonatomic, retain) DFNearbyFriendsAdapter *nearbyFriendsAdapter;
@property (nonatomic, retain) NSString *lastMessage;

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
  [self.nearbyFriendsAdapter
   fetchNearbyFriendsMessageForLocation:[[DFBackgroundLocationManager
                                          sharedBackgroundLocationManager] lastLocation]
   completionBlock:^(DFPeanutMessageResponse *response, NSError *error) {
     if (!error) {
       self.lastMessage = response.message;
     } else {
       DDLogWarn(@"%@ got an error for message fetch: %@", [[self class] description], error);
     }
   }];
}

- (NSString *)nearbyFriendsMessage
{
  [self updateNearbyFriendsMessage];
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
