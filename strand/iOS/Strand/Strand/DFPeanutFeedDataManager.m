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
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *swapsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *actionsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;


@property (atomic) BOOL inboxRefreshing;
@property (atomic) BOOL swapsRefreshing;
@property (atomic) BOOL privateStrandsRefreshing;
@property (atomic) BOOL actionsRefreshing;
@property (nonatomic, retain) NSData *inboxLastResponseHash;
@property (nonatomic, retain) NSData *swapsLastResponseHash;
@property (nonatomic, retain) NSData *privateStrandsLastResponseHash;
@property (nonatomic, retain) NSData *actionsLastResponseHash;

@property (nonatomic, retain) NSArray *inboxFeedObjects;
@property (nonatomic, retain) NSArray *swapsFeedObjects;
@property (nonatomic, retain) NSArray *privateStrandsFeedObjects;
@property (nonatomic, retain) NSArray *actionsFeedObjects;

@property (readonly, atomic, retain) NSMutableDictionary *deferredCompletionBlocks;
@property (nonatomic) dispatch_semaphore_t deferredCompletionSchedulerSemaphore;

@end

@implementation DFPeanutFeedDataManager

@synthesize inboxFeedAdapter = _inboxFeedAdapter;
@synthesize swapsFeedAdapter = _swapsFeedAdapter;
@synthesize privateStrandsFeedAdapter = _privateStrandsFeedAdapter;
@synthesize actionsFeedAdapter = _actionsFeedAdapter;

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize deferredCompletionBlocks = _deferredCompletionBlocks;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
    _deferredCompletionBlocks = [NSMutableDictionary new];
    self.deferredCompletionSchedulerSemaphore = dispatch_semaphore_create(1);
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
  DDLogVerbose(@"Refreshing all my feeds...");
  [self refreshInboxFromServer:nil];
  [self refreshSwapsFromServer:nil];
  [self refreshPrivatePhotosFromServer:nil];
  [self refreshActionsFromServer:nil];
}

- (void)refreshInboxFromServer:(RefreshCompleteCompletionBlock)completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  if (completion) [self scheduleDeferredCompletion:completion forFeedType:DFInboxFeed];
  
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
         
         DDLogInfo(@"Got new inbox data, sending notification.");
         
         [[NSNotificationCenter defaultCenter]
          postNotificationName:DFStrandNewInboxDataNotificationName
          object:self];
       }
       [self executeDeferredCompletionsForFeedType:DFInboxFeed];
       self.inboxRefreshing = NO;
     }
     ];
  }
}

- (void)refreshSwapsFromServer:(RefreshCompleteCompletionBlock)completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  if (completion) [self scheduleDeferredCompletion:completion forFeedType:DFSwapsFeed];
  
  if (!self.swapsRefreshing) {
    self.swapsRefreshing = YES;
    [self.swapsFeedAdapter
     fetchSwapsWithCompletion:^(DFPeanutObjectsResponse *response,
                                NSData *responseHash,
                                NSError *error) {
       [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
       
       if (!error && ![responseHash isEqual:self.swapsLastResponseHash]) {
         self.swapsLastResponseHash = responseHash;
         self.swapsFeedObjects = response.objects;
         
         DDLogInfo(@"Got new swaps data, sending notification.");
         
         [[NSNotificationCenter defaultCenter]
          postNotificationName:DFStrandNewSwapsDataNotificationName
          object:self];
       }
       [self executeDeferredCompletionsForFeedType:DFSwapsFeed];
       self.swapsRefreshing = NO;
     }
     ];
  }
}

- (void)refreshPrivatePhotosFromServer:(RefreshCompleteCompletionBlock)completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  if (completion) [self scheduleDeferredCompletion:completion forFeedType:DFPrivateFeed];
  
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
         
         DDLogVerbose(@"Got new private data, sending notification.");
         [[NSNotificationCenter defaultCenter]
          postNotificationName:DFStrandNewPrivatePhotosDataNotificationName
          object:self];
       }
       [self executeDeferredCompletionsForFeedType:DFPrivateFeed];
       self.privateStrandsRefreshing = NO;
     }
     ];
  }
}

// TODO(Derek): Take all this common code and put into one method
- (void)refreshActionsFromServer:(RefreshCompleteCompletionBlock)completion
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  if (completion) [self scheduleDeferredCompletion:completion forFeedType:DFActionsFeed];
  
  if (!self.actionsRefreshing) {
    self.actionsRefreshing = YES;
    [self.actionsFeedAdapter
     fetchActionsListWithCompletion:^(DFPeanutObjectsResponse *response,
                                            NSData *responseHash,
                                            NSError *error) {
       [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
       
       if (!error && ![responseHash isEqual:self.actionsLastResponseHash]) {
         self.actionsLastResponseHash = responseHash;
         self.actionsFeedObjects = response.objects;
         
         DDLogVerbose(@"Got new actions data, sending notification.");
         [[NSNotificationCenter defaultCenter]
          postNotificationName:DFStrandNewActionsDataNotificationName
          object:self];
       }
       [self executeDeferredCompletionsForFeedType:DFActionsFeed];
       self.actionsRefreshing = NO;
     }
     ];
  }
}

- (BOOL)hasInboxData{
  return (self.inboxLastResponseHash != nil);
}

- (BOOL)hasPrivateStrandData
{
  return (self.inboxLastResponseHash != nil);
}

- (BOOL)hasSwapsData
{
  return (self.swapsLastResponseHash != nil);
}

- (BOOL)hasActionsData
{
  return (self.actionsLastResponseHash != nil);
}


- (NSArray *)publicStrandsWithUser:(DFPeanutUserObject *)user includeInvites:(BOOL)includeInvites
{
  NSMutableArray *strands = [NSMutableArray new];
  
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectStrandPosts] ||
        ([object.type isEqual:DFFeedObjectInviteStrand] && includeInvites)) {
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
  
  for (DFPeanutFeedObject *object in self.swapsFeedObjects)
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
    } else {
      for (DFPeanutFeedObject *subObject in [object enumeratorOfDescendents]) {
        if ([subObject.type isEqual:DFFeedObjectPhoto] && subObject.id == photoID) {
          return subObject;
        }
      }
    }
  }
  
  for (DFPeanutFeedObject *object in self.privateStrandsFeedObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto] && object.id == photoID) {
      return object;
    } else {
      for (DFPeanutFeedObject *subObject in [object enumeratorOfDescendents]) {
        if ([subObject.type isEqual:DFFeedObjectPhoto] && subObject.id == photoID) {
          return subObject;
        }
      }
    }
  }
  
  for (DFPeanutFeedObject *object in self.swapsFeedObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto] && object.id == photoID) {
      return object;
    } else {
      for (DFPeanutFeedObject *subObject in [object enumeratorOfDescendents]) {
        if ([subObject.type isEqual:DFFeedObjectPhoto] && subObject.id == photoID) {
          return subObject;
        }
      }
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
  return [self.swapsFeedObjects filteredArrayUsingPredicate:predicate];
}

- (NSArray *)acceptedStrands
{
  return [self acceptedStrandsWithPostsCollapsed:NO
                                    filterToUser:0
                               feedObjectSortKey:@"time_stamp"
                                       ascending:NO];
}

- (NSArray *)acceptedStrandsWithPostsCollapsed:(BOOL)collapsed
                                  filterToUser:(DFUserIDType)filterToUserID
                             feedObjectSortKey:(NSString *)sortKey
                                     ascending:(BOOL)ascending;
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", DFFeedObjectStrandPosts];
  NSArray *postsObjects = [self.inboxFeedObjects filteredArrayUsingPredicate:predicate];
  if (!collapsed)return postsObjects;
  
  NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:sortKey ascending:ascending];
  NSMutableArray *collapsedResult = [NSMutableArray new];
  for (DFPeanutFeedObject *strandPosts in postsObjects) {
    if (filterToUserID > 0) {
      BOOL foundUser = NO;
      for (DFPeanutUserObject *user in strandPosts.actors) {
        if (user.id == filterToUserID) {
          foundUser = YES;
          break;
        }
      }
      if (!foundUser) continue;
    }
    DFPeanutFeedObject *collapsedObj = [strandPosts copy];
    collapsedObj.type = DFFeedObjectStrand;
    collapsedObj.actors = [strandPosts.actors copy];
    NSMutableArray *collapsedSubObjects = [NSMutableArray new];
    for (DFPeanutFeedObject *strandPost in strandPosts.objects) {
      [collapsedSubObjects addObjectsFromArray:strandPost.objects];
    }
    collapsedObj.objects = [collapsedSubObjects sortedArrayUsingDescriptors:@[sortDescriptor]];
    [collapsedResult addObject:collapsedObj];
  }
  return [collapsedResult sortedArrayUsingDescriptors:@[sortDescriptor]];
}

- (NSArray *)privateStrands
{
  return self.privateStrandsFeedObjects;
}

- (NSArray *)privatePhotos
{
  NSMutableDictionary *photos = [NSMutableDictionary new];
  
  for (DFPeanutFeedObject *object in self.privateStrandsFeedObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [photos setObject:object forKey:@(object.id)];
    } else {
      for (DFPeanutFeedObject *subObject in [object enumeratorOfDescendents]) {
        if ([subObject.type isEqual:DFFeedObjectPhoto]) {
          [photos setObject:subObject forKey:@(subObject.id)];
        }
      }
    }
  }

  return photos.allValues;
}

- (NSArray *)privateStrandsByDateAscending:(BOOL)ascending
{
  NSArray *strandsByDateAscending =
  [self.privateStrandsFeedObjects
   sortedArrayWithOptions:NSSortConcurrent
   usingComparator:^NSComparisonResult(DFPeanutFeedObject *obj1, DFPeanutFeedObject *obj2) {
     return [obj1.time_taken compare:obj2.time_taken];
   }];
  for (DFPeanutFeedObject *strandObject in strandsByDateAscending) {
    strandObject.objects = [strandObject.objects
                            sortedArrayWithOptions:NSSortConcurrent
                            usingComparator:^NSComparisonResult(DFPeanutFeedObject *obj1, DFPeanutFeedObject *obj2) {
                              return [obj1.time_taken compare:obj2.time_taken];
                            }];
  }
  
  return strandsByDateAscending;
}

- (NSArray *)suggestedStrands
{
  NSPredicate *predicate = [NSPredicate
                            predicateWithFormat:@"type == %@", DFFeedObjectSwapSuggestion];
  NSArray *suggestibleStrands = [self.swapsFeedObjects filteredArrayUsingPredicate:predicate];
  return [suggestibleStrands sortedArrayUsingComparator:
          ^NSComparisonResult(DFPeanutFeedObject *obj1, DFPeanutFeedObject *obj2) {
            if (obj1.suggestion_rank && !obj2.suggestion_rank) {
              return NSOrderedAscending;
            } else if (obj2.suggestion_rank && !obj2.suggestion_rank) {
              return NSOrderedDescending;
            } else {
              return [obj1.suggestion_rank compare:obj2.suggestion_rank];
            }
  }];
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

- (NSArray *)actionsList
{
  return [self actionsListFilterUser:nil];
}

- (NSArray *)actionsListFilterUser:(DFPeanutUserObject *)user
{
  DFPeanutFeedObject *actionsList = [self.actionsFeedObjects firstObject];
  NSMutableArray *actions = [NSMutableArray new];
  
  for (DFPeanutAction *action in actionsList.actions) {
    if (action.user == user.id) continue;
    [actions addObject:action];
  }
  
  return actions;
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

- (void)addFeedObjects:(NSArray *)feedObjects
         toStrandPosts:(DFPeanutFeedObject *)strandPosts
               success:(DFSuccessBlock)success
               failure:(DFFailureBlock)failure
{
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.id = @(strandPosts.id);
  
  NSMutableArray *photoIDs = [NSMutableArray new];
  for (DFPeanutFeedObject *feedObject in feedObjects) {
    if ([feedObject.type isEqual:DFFeedObjectPhoto]) {
      [photoIDs addObject:@(feedObject.id)];
    } else {
      NSArray *photoObjects = [feedObject descendentdsOfType:DFFeedObjectPhoto];
      [photoIDs addObjectsFromArray:[photoObjects arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *photoObject) {
        return @(photoObject.id);
      }]];
    }
  }
  
  [self.strandAdapter
   performRequest:RKRequestMethodGET
   withPeanutStrand:requestStrand
   success:^(DFPeanutStrand *peanutStrand) {
     // add any selected photos to the list of shared photos
     NSMutableSet *newPhotoIDs = [[NSMutableSet alloc] initWithArray:peanutStrand.photos];
     [newPhotoIDs addObjectsFromArray:photoIDs];
     peanutStrand.photos = [newPhotoIDs allObjects];
     
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

- (void)createNewStrandWithFeedObjects:(NSArray *)feedObjects
           createdFromSuggestions:(NSArray *)suggestedSections
                     selectedPeanutContacts:(NSArray *)selectedPeanutContacts
                          success:(void(^)(DFPeanutStrand *resultStrand))success
                          failure:(DFFailureBlock)failure

{
  // Create the strand
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.users = @[@([[DFUser currentUser] userID])];
  NSMutableArray *photoObjects = [NSMutableArray new];
  for (DFPeanutFeedObject *feedObject in feedObjects) {
    [photoObjects addObjectsFromArray:[feedObject leafNodesFromObjectOfType:DFFeedObjectPhoto]];
  }
  
  requestStrand.photos = [photoObjects arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *photoObject) {
    return @(photoObject.id);
  }];
  requestStrand.private = @(NO);
  [self setTimesForStrand:requestStrand fromPhotoObjects:photoObjects];
  
  [self.strandAdapter
   performRequest:RKRequestMethodPOST
   withPeanutStrand:requestStrand
   success:^(DFPeanutStrand *peanutStrand) {
     DDLogInfo(@"%@ successfully created strand: %@", self.class, peanutStrand);
     
     [[NSNotificationCenter defaultCenter]
      postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
      object:self];
     
     // start uploading the photos
     [[DFPhotoStore sharedStore] markPhotosForUpload:peanutStrand.photos];
     [[DFPhotoStore sharedStore] cachePhotoIDsInImageStore:peanutStrand.photos];
     success(peanutStrand);
   } failure:^(NSError *error) {
     failure(error);
     DDLogError(@"%@ failed to create strand: %@, error: %@",
                self.class, requestStrand, error);
   }];
}

- (void)removePhoto:(DFPeanutFeedObject *)photoObject
     fromStrandPosts:(DFPeanutFeedObject *)strandPosts
            success:(DFSuccessBlock)success
            failure:(DFFailureBlock)failure
{
  DFPeanutStrand *reqStrand = [[DFPeanutStrand alloc] init];
  reqStrand.id = @(strandPosts.id);
  
  DDLogInfo(@"Going to delete photo %llu", photoObject.id);
  
  // first get the strand
  [self.strandAdapter
   performRequest:RKRequestMethodGET
   withPeanutStrand:reqStrand success:^(DFPeanutStrand *peanutStrand) {
     //remove the photo from the strand's list of photos
     NSMutableArray *newPhotosList = [peanutStrand.photos mutableCopy];
     [newPhotosList removeObject:@(photoObject.id)];
     peanutStrand.photos = newPhotosList;

     // patch the strand with the new list
     [self.strandAdapter
      performRequest:RKRequestMethodPATCH
      withPeanutStrand:peanutStrand success:^(DFPeanutStrand *peanutStrand) {
        DDLogInfo(@"%@ removed photo %@ from %@", self.class, photoObject, peanutStrand);
        success();
      } failure:^(NSError *error) {
        DDLogError(@"%@ couldn't patch strand: %@", self.class, error);
        failure(error);
      }];
   } failure:^(NSError *error) {
     DDLogError(@"%@ couldn't get strand: %@", self.class, error);
     failure(error);
   }];
}

- (void)setTimesForStrand:(DFPeanutStrand *)strand fromPhotoObjects:(NSArray *)objects
{
  NSDate *minDateFound;
  NSDate *maxDateFound;
  
  for (DFPeanutFeedObject *object in objects) {
    if (!minDateFound || [object.time_taken compare:minDateFound] == NSOrderedAscending) {
      minDateFound = object.time_taken;
    }
    if (!maxDateFound || [object.time_taken compare:maxDateFound] == NSOrderedDescending) {
      maxDateFound = object.time_taken;
    }
  }
  
  strand.first_photo_time = minDateFound;
  strand.last_photo_time = maxDateFound;
}


- (void)scheduleDeferredCompletion:(RefreshCompleteCompletionBlock)completion forFeedType:(DFFeedType)feedType
{
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);
  NSMutableArray *deferredForID = self.deferredCompletionBlocks[@(feedType)];
  if (!deferredForID) {
    deferredForID = [[NSMutableArray alloc] init];
    self.deferredCompletionBlocks[@(feedType)] = deferredForID;
  }
  
  [deferredForID addObject:[completion copy]];
  dispatch_semaphore_signal(self.deferredCompletionSchedulerSemaphore);
}

- (void)executeDeferredCompletionsForFeedType:(DFFeedType)feedType
{
  dispatch_semaphore_wait(self.deferredCompletionSchedulerSemaphore, DISPATCH_TIME_FOREVER);
  NSMutableArray *deferredForID = self.deferredCompletionBlocks[@(feedType)];
  for (RefreshCompleteCompletionBlock completion in deferredForID) {
    completion();
  }
  [deferredForID removeAllObjects];
  dispatch_semaphore_signal(self.deferredCompletionSchedulerSemaphore);
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

- (DFPeanutFeedAdapter *)swapsFeedAdapter
{
  if (!_swapsFeedAdapter) _swapsFeedAdapter = [[DFPeanutFeedAdapter alloc] init];
  return _swapsFeedAdapter;
}

- (DFPeanutFeedAdapter *)actionsFeedAdapter
{
  if (!_actionsFeedAdapter) _actionsFeedAdapter = [[DFPeanutFeedAdapter alloc] init];
  return _actionsFeedAdapter;
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

