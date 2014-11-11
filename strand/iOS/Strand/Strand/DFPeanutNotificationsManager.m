//
//  DFPeanutNotificationsManager.m
//  Strand
//
//  Created by Derek Parham on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutNotificationsManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFStrandConstants.h"
#import "DFDefaultsStore.h"

NSTimeInterval const DFNotificationsMinFetchInterval = 2.0;

@interface DFPeanutNotificationsManager ()

@property (nonatomic, retain) NSArray *peanutActions;
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateNotifications)
                                                 name:DFStrandReloadRemoteUIRequestedNotificationName
                                               object:nil];

  }
  return self;
}

- (void)updateNotifications
{
  self.peanutActions = [[DFPeanutFeedDataManager sharedManager] actionsList];
  [[NSNotificationCenter defaultCenter]
   postNotificationName:DFStrandNotificationsUpdatedNotification
   object:self
   userInfo:@{DFStrandNotificationsUnseenCountKey: @(self.unreadNotifications.count)}];
}

/*
 * Returns the current set of notifications
 */
- (NSArray *)notifications
{
  if (!self.peanutActions) {
    [self updateNotifications];
  }

  return self.peanutActions;
}

/*
 * Compare all the current notifications to the last time the user viewed the page, return back ones
 *   that are after that date.
 */
- (NSArray *)unreadNotifications
{
  NSMutableArray *unreadNotifications = [NSMutableArray new];
  
  for (int x=0; x < self.notifications.count; x++) {
    DFPeanutAction *action = (DFPeanutAction *)self.notifications[x];
    if ([self.lastViewDate compare:action.time_stamp] == NSOrderedAscending) {
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
    DFPeanutAction *action = (DFPeanutAction *)self.notifications[x];
    if ([self.lastViewDate compare:action.time_stamp] == NSOrderedDescending) {
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
