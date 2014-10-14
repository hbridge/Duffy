//
//  DFInboxDataManager.m
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutFeedDataManager.h"

#import "DFPeanutStrandFeedAdapter.h"
#import "DFStrandConstants.h"
#import "DFPeanutUserObject.h"

@interface DFPeanutFeedDataManager ()

@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *inboxFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *privatePhotosFeedAdapter;
@property (nonatomic, retain) NSData *inboxLastResponseHash;
@property (nonatomic, retain) NSData *privatePhotosLastResponseHash;

@end

@implementation DFPeanutFeedDataManager

@synthesize inboxFeedAdapter = _inboxFeedAdapter;
@synthesize privatePhotosFeedAdapter = _privatePhotosFeedAdapter;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
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
  [self refreshFromServer:nil];
}

- (void)refreshFromServer:(void(^)(void))completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  
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
   }
  ];
}

- (BOOL)hasData{
  return self.inboxLastResponseHash;
}

- (NSArray *)strandsWithUser:(DFPeanutUserObject *)user
{
  NSMutableArray *strands = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectStrandPosts]) {
      for (NSUInteger i = 0; i < object.actors.count; i++) {
        DFPeanutUserObject *actor = object.actors[i];
        if (user.id == actor.id) {
          [strands addObject:object];
        }
      }
    } else if ([object.type isEqual:DFFeedObjectInviteStrand]) {

    }
  }
  
  return strands;
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

#pragma mark - Network Adapter

- (DFPeanutStrandFeedAdapter *)inboxFeedAdapter
{
  if (!_inboxFeedAdapter) _inboxFeedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  return _inboxFeedAdapter;
}

- (DFPeanutStrandFeedAdapter *)privatePhotosFeedAdapter
{
  if (!_privatePhotosFeedAdapter) _privatePhotosFeedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  return _privatePhotosFeedAdapter;
}

@end

