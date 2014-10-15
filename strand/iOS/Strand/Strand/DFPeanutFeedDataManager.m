//
//  DFInboxDataManager.m
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutFeedDataManager.h"

#import "DFPeanutFeedAdapter.h"
#import "DFStrandConstants.h"
#import "DFPeanutUserObject.h"

@interface DFPeanutFeedDataManager ()

@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *inboxFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *privateStrandsFeedAdapter;

@property (atomic) BOOL inboxRefreshing;
@property (atomic) BOOL privateStrandsRefreshing;
@property (nonatomic, retain) NSData *inboxLastResponseHash;
@property (nonatomic, retain) NSData *privateStrandsLastResponseHash;

@property (nonatomic, retain) NSArray *inboxFeedObjects;
@property (nonatomic, retain) NSArray *privateStrandsFeedObjects;

@end

@implementation DFPeanutFeedDataManager

@synthesize inboxFeedAdapter = _inboxFeedAdapter;
@synthesize privateStrandsFeedAdapter = _privateStrandsFeedAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
    [self refreshFromServer];
  }
  return self;
}

static DFPeanutFeedDataManager *defaultManager;
+ (DFPeanutFeedDataManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(refreshFromServer)
                                               name:DFStrandReloadRemoteUIRequestedNotificationName
                                             object:nil];
}

#pragma mark - Data Fetch

- (void)refreshFromServer
{
  [self refreshInboxFromServer:nil];
  [self refreshPrivatePhotosFromServer:nil];
}

- (void)refreshInboxFromServer:(void(^)(void))completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  
  if (!self.inboxRefreshing) {
    self.inboxRefreshing = YES;
    [self.inboxFeedAdapter
     fetchInboxWithCompletion:^(DFPeanutObjectsResponse *response,
                                NSData *responseHash,
                                NSError *error) {
       [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
       
       if (!error && ![responseHash isEqual:self.inboxLastResponseHash]) {
         self.inboxLastResponseHash = responseHash;
         self.inboxFeedObjects = response.objects;
         
         [[NSNotificationCenter defaultCenter]
          postNotificationName:DFStrandNewInboxDataNotificationName
          object:self];
       }
       if (completion) completion();
       self.inboxRefreshing = NO;
     }
     ];
  }
}

- (void)refreshPrivatePhotosFromServer:(void(^)(void))completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  
  if (!self.privateStrandsRefreshing) {
    self.privateStrandsRefreshing = YES;
    [self.privateStrandsFeedAdapter
     fetchAllPrivateStrandsWithCompletion:^(DFPeanutObjectsResponse *response,
                                            NSData *responseHash,
                                            NSError *error) {
       [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
       
       if (!error && ![responseHash isEqual:self.privateStrandsLastResponseHash]) {
         self.privateStrandsLastResponseHash = responseHash;
         self.privateStrandsFeedObjects = response.objects;
         
         [[NSNotificationCenter defaultCenter]
          postNotificationName:DFStrandNewPrivatePhotosDataNotificationName
          object:self];
       }
       if (completion) completion();
       self.privateStrandsRefreshing = NO;
     }
     ];
  }
}

- (BOOL)hasData{
  return self.inboxLastResponseHash;
}

- (NSArray *)publicStrandsWithUser:(DFPeanutUserObject *)user
{
  NSMutableArray *strands = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectStrandPosts] || [object.type isEqual:DFFeedObjectInviteStrand]) {
      for (NSUInteger i = 0; i < object.actors.count; i++) {
        DFPeanutUserObject *actor = object.actors[i];
        if (user.id == actor.id) {
          [strands addObject:object];
        }
      }
    }
  }
  
  return strands;
}

- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user
{
  NSMutableArray *strands = [NSMutableArray new];

  for (DFPeanutFeedObject *object in self.privateStrandsFeedObjects) {
    for (NSUInteger i = 0; i < object.actors.count; i++) {
      DFPeanutUserObject *actor = object.actors[i];
      if (user.id == actor.id) {
        [strands addObject:object];
      }
    }
  }
  
  return strands;
}

- (DFPeanutFeedObject *)strandPostsObjectWithId:(DFStrandIDType)strandPostsId
{
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectStrandPosts] && object.id == strandPostsId) {
      return object;
    }
  }
  return nil;
}

- (NSArray *)publicStrands
{
  NSMutableArray *strands = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectStrandPosts] || [object.type isEqual:DFFeedObjectInviteStrand]) {
      [strands addObject:object];
    }
  }
  return strands;
}

- (NSArray *)privateStrands
{
  return self.privateStrandsFeedObjects;
}

- (NSArray *)friendsList
{
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectFriendsList]) {
      return object.actors;
    }
  }
  return [NSArray new];
}

- (BOOL)isRefreshingInbox
{
  return self.inboxRefreshing;
}

#pragma mark - Network Adapter

- (DFPeanutFeedAdapter *)inboxFeedAdapter
{
  if (!_inboxFeedAdapter) _inboxFeedAdapter = [[DFPeanutFeedAdapter alloc] init];
  return _inboxFeedAdapter;
}

- (DFPeanutFeedAdapter *)privateStrandsFeedAdapter
{
  if (!_privateStrandsFeedAdapter) _privateStrandsFeedAdapter = [[DFPeanutFeedAdapter alloc] init];
  return _privateStrandsFeedAdapter;
}

@end

