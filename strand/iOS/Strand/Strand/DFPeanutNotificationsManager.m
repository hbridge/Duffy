//
//  DFPeanutNotificationsManager.m
//  Strand
//
//  Created by Derek Parham on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutNotificationsManager.h"
#import "DFPeanutNotificationsAdapter.h"
#import "DFStrandConstants.h"

NSTimeInterval const DFNotificationsMinFetchInterval = 2.0;

@interface DFPeanutNotificationsManager ()

@property (nonatomic, retain) DFPeanutNotificationsAdapter *notificationsAdapter;
@property (nonatomic, retain) NSArray *peanutNotifications;
@property (nonatomic, retain) NSDate *lastFetchDate;
@property (atomic) BOOL isUpdatingNotifications;

@end

@implementation DFPeanutNotificationsManager

static DFPeanutNotificationsManager *defaultManager;

+ (DFPeanutNotificationsManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self updateNotifications];
  }
  return self;
}

- (void)updateNotifications
{
  if (self.isUpdatingNotifications) return;
  
  self.isUpdatingNotifications = YES;
  
  [self.notificationsAdapter fetchNotifications:^(NSArray *peanutNotifications) {
    self.peanutNotifications = peanutNotifications;
    DDLogInfo(@"Fetching %d notifications succeeded.", (int)peanutNotifications.count);
    self.isUpdatingNotifications = NO;
    self.lastFetchDate = [NSDate date];
    
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandNotificationsUpdatedNotification
     object:self
     userInfo:@{DFStrandNotificationsUnseenCountKey: @(self.unreadNotifications.count)}];
  } failure:^(NSError *error) {
    DDLogError(@"%@ fetching contacts failed: %@", [self.class description], error.description);
    self.isUpdatingNotifications = NO;
  }];
}

- (NSArray *)notifications
{
  if (!self.peanutNotifications ||
      [[NSDate date] timeIntervalSinceDate:self.lastFetchDate] > DFNotificationsMinFetchInterval) {
    [self updateNotifications];
  }
  return self.peanutNotifications;
}

- (DFPeanutNotificationsAdapter *)notificationsAdapter
{
  if (!_notificationsAdapter) {
    _notificationsAdapter = [DFPeanutNotificationsAdapter new];
  }
  
  return _notificationsAdapter;
}

- (NSArray *)unreadNotifications
{
  // TODO (dparham) make this return
  return self.notifications;
}

- (NSArray *)readNotifications
{
  // TODO (dparham) make this return the right set of notifications
  
  return self.notifications;
}


@end
