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
#import "DFDefaultsStore.h"

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

/*
 * Returns the current set of notifications
 */
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

/*
 * Compare all the current notifications to the last time the user viewed the page, return back ones
 *   that are after that date.
 */
- (NSArray *)unreadNotifications
{
  NSMutableArray *unreadNotifications = [NSMutableArray new];
  
  for (int x=0; x < self.notifications.count; x++) {
    if ([self.lastViewDate compare: ((DFPeanutNotification *)self.notifications[x]).time] == NSOrderedAscending) {
      [unreadNotifications addObject:self.notifications[x]];
    }
  }
  return unreadNotifications;
}

/*
 * Compare all the current notifications to the last time the user viewed the page, return back ones
 *   that are before that date.
 */
- (NSArray *)readNotifications
{
  NSMutableArray *readNotifications = [NSMutableArray new];
  
  for (int x=0; x < self.notifications.count; x++) {
    if ([self.lastViewDate compare: ((DFPeanutNotification *)self.notifications[x]).time] == NSOrderedDescending) {
      [readNotifications addObject:self.notifications[x]];
    }
  }
  return readNotifications;
}

/*
 * Last date that notifications were viewed, this is set by using the markNotificationsAsRead method
 */
- (NSDate *)lastViewDate
{
  NSDate *lastViewDate = [DFDefaultsStore lastDateForAction:DFUserActionViewNotifications];
  if (lastViewDate == nil) {
    return [[NSDate alloc] initWithTimeIntervalSince1970:0];
  } else {
    return lastViewDate;
  }
}

/*
 * This should be called when the notifications view is shown to the user.
 */
- (void)markNotificationsAsRead
{
  [DFDefaultsStore setLastDate:[NSDate date] forAction:DFUserActionViewNotifications];
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}

@end
