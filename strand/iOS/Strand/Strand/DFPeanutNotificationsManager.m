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
#import <FMDB/FMDB.h>

NSTimeInterval const DFNotificationsMinFetchInterval = 2.0;

@interface DFPeanutNotificationsManager ()

@property (nonatomic, retain) NSArray *peanutActions;
@property (nonatomic, retain) NSDate *lastFetchDate;
@property (atomic) BOOL isUpdatingNotifications;
@property (nonatomic, readonly, retain) FMDatabase *db;

@end

@implementation DFPeanutNotificationsManager
@synthesize db = _db;

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateNotifications)
                                                 name:DFStrandNewActionsDataNotificationName
                                               object:nil];

  }
  return self;
}

- (void)updateNotifications
{
  DFPeanutUserObject *user = [[DFPeanutUserObject alloc] init];
  user.id = [[DFUser currentUser] userID];
  self.peanutActions = [[DFPeanutFeedDataManager sharedManager] actionsListFilterUser:user];
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
- (void)markAllNotificationsAsRead
{
  [DFDefaultsStore setLastDate:[NSDate date] forAction:DFUserActionViewNotifications];
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}


- (NSArray *)actionsWithReadState:(BOOL)state
{
  //FMResultSet *actionIDs = [self.db executeQuery:@"SELECT action_id FROM seenNotifications WHERE user_id=(?) AND isSeen IS 1", @(user.id)];
  return nil;
}

- (FMDatabase *)db
{
  if (!_db) {
    _db = [FMDatabase databaseWithPath:[self.class dbPath]];
    
    if (![_db open]) {
      DDLogError(@"Error opening seen database.");
      _db = nil;
    }
    if (![_db tableExists:@"seenNotifications"]) {
      [_db executeUpdate:@"CREATE TABLE seenNotifications (action_id NUMBER, strand_id NUMBER, photo_id NUMBER)"];
    }
  }
  return _db;
}



- (NSArray *)seenPrivateStrandIDsForUser:(DFPeanutUserObject *)user
{
  FMResultSet *results = [self.db executeQuery:@"SELECT strand_id FROM seenPeopleSuggestions WHERE user_id=(?) AND isSeen IS 1", @(user.id)];
  NSMutableArray *resultIDs = [NSMutableArray new];
  while ([results next]) {
    [resultIDs addObject:@([results longLongIntForColumn:@"strand_id"])];
  }
  return resultIDs;
}

- (void)addSeenPrivateStrandIDs:(NSArray *)privateStrandIDs forUser:(DFPeanutUserObject *)user
{
  for (NSNumber *privateStrandID in privateStrandIDs) {
    NSString *key = [NSString stringWithFormat:@"%@-%llu", privateStrandID, user.id];
    [self.db executeUpdate:@"INSERT INTO seenPeopleSuggestions VALUES (?, ?, ?, ?)",
     key,
     privateStrandID,
     @(user.id),
     @(YES)];
  }
}

+ (NSString *)dbPath
{
  NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSURL *dbURL = [documentsURL URLByAppendingPathComponent:@"seenNotifications.db"];
  return [dbURL path];
}

- (void)markNotificationsSeen:(NSArray *)notifications
{
  
}


@end
