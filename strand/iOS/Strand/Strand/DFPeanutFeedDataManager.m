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
#import "DFPeanutStrand.h"
#import "DFPeanutStrandAdapter.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFPhotoStore.h"

@interface DFPeanutFeedDataManager ()

@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *inboxFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *privateStrandsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;

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
@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;

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
  return (self.inboxLastResponseHash != nil);
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
      if (user.id == actor.id && [object.suggestible isEqual:@(YES)]) {
        [strands addObject:object];
      }
    }
  }
  
  return strands;
}

- (NSArray *)remotePhotos
{
  NSMutableArray *photos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in self.inboxFeedObjects)
  {
    if ([object.type isEqual:DFFeedObjectPhoto] && object.user != [[DFUser currentUser] userID]) {
      [photos addObject:object];
      continue;
    }
    for (DFPeanutFeedObject *subObject in object.enumeratorOfDescendents.allObjects) {
      if ([subObject.type isEqual:DFFeedObjectPhoto] && subObject.user != [[DFUser currentUser] userID]) {
        [photos addObject:subObject];
      }
    }
  }
  
  return photos;
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

- (DFPeanutFeedObject *)inviteObjectWithId:(DFInviteIDType)inviteId
{
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectInviteStrand] && object.id == inviteId) {
      return object;
    }
  }
  return nil;
}

- (DFPeanutFeedObject *)photoWithId:(DFPhotoIDType)photoID
{
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto] && object.id == photoID) {
      return object;
    }
  }
  
  for (DFPeanutFeedObject *object in self.privateStrandsFeedObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto] && object.id == photoID) {
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

- (NSArray *)inviteStrands
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", DFFeedObjectInviteStrand];
  return [self.inboxFeedObjects filteredArrayUsingPredicate:predicate];
}

- (NSArray *)acceptedStrands
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", DFFeedObjectStrandPosts];
  return [self.inboxFeedObjects filteredArrayUsingPredicate:predicate];
}

- (NSArray *)privateStrands
{
  return self.privateStrandsFeedObjects;
}

- (NSArray *)suggestedStrands
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"actors.@count > 0 AND suggestible == 1"];
  return [self.privateStrandsFeedObjects filteredArrayUsingPredicate:predicate];
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



- (void)acceptInvite:(DFPeanutFeedObject *)inviteFeedObject
         addPhotoIDs:(NSArray *)photoIDs
             success:(void(^)(void))success
             failure:(void(^)(NSError *error))failure
{
  DFPeanutFeedObject *invitedStrandPosts = [[inviteFeedObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.id = @(invitedStrandPosts.id);
  
  [self.strandAdapter
   performRequest:RKRequestMethodGET
   withPeanutStrand:requestStrand
   success:^(DFPeanutStrand *peanutStrand) {
     // add current user to list of users if not there
     NSNumber *userID = @([[DFUser currentUser] userID]);
     if (![peanutStrand.users containsObject:userID]) {
       peanutStrand.users = [peanutStrand.users arrayByAddingObject:userID];
     }
     
     // add any selected photos to the list of shared photos
     if (photoIDs.count > 0) {
       NSMutableSet *newPhotoIDs = [[NSMutableSet alloc] initWithArray:peanutStrand.photos];
       [newPhotoIDs addObjectsFromArray:photoIDs];
       peanutStrand.photos = [newPhotoIDs allObjects];
     }
     
     // Patch the new peanut strand
     [self.strandAdapter
      performRequest:RKRequestMethodPATCH withPeanutStrand:peanutStrand
      success:^(DFPeanutStrand *peanutStrand) {
        DDLogInfo(@"%@ successfully added photos to strand: %@", self.class, peanutStrand);
        // cache the photos locally
        [[DFPhotoStore sharedStore] cachePhotoIDsInImageStore:photoIDs];
        
        // even if there is an invite, you've been joined to the strand, so we count
        //  either result of the invite marking as success
        success();
        [[NSNotificationCenter defaultCenter]
         postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
         object:self];
        [[DFPhotoStore sharedStore] markPhotosForUpload:photoIDs];

        // now mark the invite as used
        if (inviteFeedObject) {
          [self.inviteAdapter
           markInviteWithIDUsed:@(inviteFeedObject.id)
           success:^(NSArray *resultObjects) {
             DDLogInfo(@"Marked invite used: %@", resultObjects.firstObject);
             [[NSNotificationCenter defaultCenter]
              postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
              object:self];
           } failure:^(NSError *error) {
             DDLogError(@"Failed to mark invite used: %@", error);
           }];
        }
      } failure:^(NSError *error) {
        DDLogError(@"%@ failed to patch strand: %@, error: %@",
                   self.class, peanutStrand, error);
      }];
   } failure:^(NSError *error) {
     DDLogError(@"%@ failed to get strand: %@, error: %@",
                self.class, requestStrand, error);
   }];
}

- (void)markSuggestion:(DFPeanutFeedObject *)suggestedSection visible:(BOOL)visible
{
  DFPeanutStrand *privateStrand = [[DFPeanutStrand alloc] init];
  privateStrand.id = @(suggestedSection.id);
  
  [self.strandAdapter
   performRequest:RKRequestMethodGET
   withPeanutStrand:privateStrand
   success:^(DFPeanutStrand *peanutStrand) {
     peanutStrand.suggestible = @(NO);
     
     // Patch the peanut strand
     [self.strandAdapter
      performRequest:RKRequestMethodPATCH withPeanutStrand:peanutStrand
      success:^(DFPeanutStrand *peanutStrand) {
        DDLogInfo(@"%@ successfully updated private strand to set visible false: %@", self.class, peanutStrand);
      } failure:^(NSError *error) {
        DDLogError(@"%@ failed to patch private strand: %@, error: %@",
                   self.class, peanutStrand, error);
      }];
   } failure:^(NSError *error) {
     DDLogError(@"%@ failed to get private strand: %@, error: %@",
                self.class, privateStrand, error);
   }];
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

- (DFPeanutStrandAdapter *)strandAdapter
{
  if (!_strandAdapter) _strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  return _strandAdapter;
}

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}

@end

