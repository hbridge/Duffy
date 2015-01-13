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
@property (nonatomic, readonly, retain) FMDatabaseQueue *dbQueue;
@property (nonatomic, retain) NSMutableSet *seenActionIDs;

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
    // force db to init
    self.seenActionIDs = [[self allSeenActionIDs] mutableCopy];
    [self updateNotifications];
  }
  return self;
}

- (void)updateNotifications
{
  DFPeanutUserObject *user = [[DFPeanutUserObject alloc] init];
  user.id = [[DFUser currentUser] userID];
  self.peanutActions = [[DFPeanutFeedDataManager sharedManager] actionsListFilterUser:user];
  [self postNotificationsUpdatedNotif];
}

- (void)postNotificationsUpdatedNotif
{
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
  return [self actionsWithReadState:NO];
}

/*
 * Compare all the current notifications to the last time the user viewed the page, return back ones
 *   that are before that date.
 */
- (NSArray *)readNotifications
{
  return [self actionsWithReadState:YES];
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

- (void)markAllNotificationsAsRead
{
  
}


- (NSArray *)actionsWithReadState:(BOOL)isRead
{
  NSArray *actionIDs = [self.notifications arrayByMappingObjectsWithBlock:^id(DFPeanutAction *action) {
    return action.id;
  }];
  
  NSMutableSet *resultSet = [[NSMutableSet alloc] initWithArray:actionIDs];
  if (isRead) {
    [resultSet intersectSet:self.seenActionIDs];
  } else {
    [resultSet minusSet:self.seenActionIDs];
  }
  
  NSMutableArray *resultActions = [NSMutableArray new];
  for (DFPeanutAction *action in self.notifications ) {
    if ([resultSet containsObject:action.id]) {
      [resultActions addObject:action];
    }
  }
  
  return resultActions;
}

- (BOOL)isActionIDSeen:(DFActionID)actionID
{
  return [self.seenActionIDs containsObject:@(actionID)];
}

- (void)markActionIDsSeen:(NSArray *)actionIDs
{
  [self.dbQueue inDatabase:^(FMDatabase *db) {
    BOOL added = NO;
    for (NSNumber *actionID in actionIDs) {
      if (![self.seenActionIDs containsObject:actionID]) {
        [self.seenActionIDs addObject:actionID];
        [self.db executeUpdate:@"INSERT INTO seenNotifications VALUES (?)",
         actionID];
        added = YES;
      }
    }
    if (added)
      dispatch_async(dispatch_get_main_queue(), ^{
        [self postNotificationsUpdatedNotif];
      });
  }];
}

#pragma mark - DB accessor

- (FMDatabase *)db
{
  if (!_db) {
    _db = [FMDatabase databaseWithPath:[self.class dbPath]];
    
    if (![_db open]) {
      DDLogError(@"Error opening seen database.");
      _db = nil;
    }
    if (![_db tableExists:@"seenNotifications"]) {
      [_db executeUpdate:@"CREATE TABLE seenNotifications (action_id NUMBER UNIQUE, PRIMARY KEY (action_id))"];
    }
  }
  _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[self.class dbPath]];
  
  return _db;
}

- (NSSet *)seenActionIDsWithQuery:(NSString *)queryString
{
  FMResultSet *fetchResult = [self.db executeQuery:queryString];
  NSMutableSet *seenActionIDSet = [NSMutableSet new];
  while ([fetchResult next]) {
    [seenActionIDSet addObject:@([fetchResult longLongIntForColumn:@"action_id"])];
  }
  return seenActionIDSet;
}

- (NSSet *)allSeenActionIDs
{
  NSString *queryString = [NSString stringWithFormat:@"SELECT action_id FROM seenNotifications"];
  return [self seenActionIDsWithQuery:queryString];
}

- (NSSet *)seenActionIDsInArray:(NSArray *)actionIDs
{
  NSString *actionIDString = [actionIDs componentsJoinedByString:@","];
  NSString *queryString = [NSString stringWithFormat:@"SELECT action_id FROM seenNotifications WHERE action_id IN (%@)", actionIDString];
  return [self seenActionIDsWithQuery:queryString];
}

+ (NSString *)dbPath
{
  NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSURL *dbURL = [documentsURL URLByAppendingPathComponent:@"seenNotifications.db"];
  return [dbURL path];
}



@end
