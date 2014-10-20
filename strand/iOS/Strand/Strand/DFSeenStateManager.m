//
//  DFSeenStateManager.m
//  Strand
//
//  Created by Henry Bridge on 10/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSeenStateManager.h"
#import <FMDB/FMDB.h>


@interface DFSeenStateManager()

@property (nonatomic, readonly, retain) FMDatabase *db;

@end


@implementation DFSeenStateManager
@synthesize db = _db;


+ (DFSeenStateManager *)sharedManager
{
  static DFSeenStateManager *sharedManager = nil;
  if (!sharedManager) {
    sharedManager = [[super allocWithZone:nil] init];
  }
  return sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
}


- (FMDatabase *)db
{
  if (!_db) {
    _db = [FMDatabase databaseWithPath:[self.class dbPath]];
  
    if (![_db open]) {
      DDLogError(@"Error opening seen database.");
      _db = nil;
    }
    if (![_db tableExists:@"seenPeopleSuggestions"]) {
      [_db executeUpdate:@"CREATE TABLE seenPeopleSuggestions (strandIDAndUserID TEXT, strand_id NUMBER, user_id NUMBER, isSeen BOOL)"];
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
  NSURL *dbURL = [documentsURL URLByAppendingPathComponent:@"seen.db"];
  return [dbURL path];
}

@end
