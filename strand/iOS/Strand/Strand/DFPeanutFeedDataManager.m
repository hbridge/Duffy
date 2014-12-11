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
#import "DFPeanutSharedStrandAdapter.h"
#import "DFPeanutActionAdapter.h"
#import "DFPhotoStore.h"
#import "DFPhoneNumberUtils.h"
#import "DFAnalytics.h"

@interface DFPeanutFeedDataManager ()

@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *inboxFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *privateStrandsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *swapsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *actionsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutActionAdapter *actionAdapter;
@property (readonly, nonatomic, retain) DFPeanutSharedStrandAdapter *sharedStrandAdapter;


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

@property (nonatomic, retain) NSArray *cachedFriendsList;
@end

@implementation DFPeanutFeedDataManager

@synthesize inboxFeedAdapter = _inboxFeedAdapter;
@synthesize swapsFeedAdapter = _swapsFeedAdapter;
@synthesize privateStrandsFeedAdapter = _privateStrandsFeedAdapter;
@synthesize actionsFeedAdapter = _actionsFeedAdapter;

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize actionAdapter = _actionAdapter;
@synthesize sharedStrandAdapter = _sharedStrandAdapter;

@synthesize cachedFriendsList = _cachedFriendsList;

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
         
         // For inbox only, we update our local cache of friends
         // If we refactor these methods to be common this will need to be pulled out
         for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
           if ([object.type isEqual:DFFeedObjectFriendsList]) {
             // This grabs the local first name which we want to sort by
             NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES];
             _cachedFriendsList = [NSMutableArray arrayWithArray:[object.actors sortedArrayUsingDescriptors:@[sort]]];
           }
         }
         
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
         
         DDLogInfo(@"Got new swaps data for %@ objects, sending notification.", @(response.objects.count));
         
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

- (BOOL)areSuggestionsReady
{
  NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
  DFPhotoCollection *allPhotos = [DFPhotoStore allPhotosCollectionUsingContext:context];
  NSArray *photosWithoutIDs =
   [DFPhotoStore photosWithoutPhotoIDInContext:[DFPhotoStore createBackgroundManagedObjectContext]];
  BOOL result =
  // if there are no photos to upload and we have swaps data, or there are suggestions, suggestions should be ready
  ((allPhotos.photoSet.count > 0 && photosWithoutIDs.count == 0 && self.hasSwapsData)
   || self.suggestedStrands.count > 0);

  
  DDLogVerbose(@"areSuggestionsReady: %@, allPhotos:%@ photosWithoutIDs:%@ hasSwapsData:%@ suggestedStrands:%@",
               @(result), @(allPhotos.photoSet.count), @(photosWithoutIDs.count), @(self.hasSwapsData), @(self.suggestedStrands.count));
  return result;
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

- (DFPeanutFeedObject *)photoWithID:(DFPhotoIDType)photoID inStrand:(DFStrandIDType)strandID
{
  DFPeanutFeedObject *strandposts = [self strandPostsObjectWithId:strandID];
  NSArray *photoObjects = [strandposts leafNodesFromObjectOfType:DFFeedObjectPhoto];
  for (DFPeanutFeedObject *photo in photoObjects) {
    if (photo.id == photoID) {
      return photo;
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

- (NSArray *)unevaluatedPhotosFromOtherUsers
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFPeanutUserObject *user in self.friendsList) {
    NSArray *strands = [[DFPeanutFeedDataManager sharedManager] publicStrandsWithUser:user includeInvites:NO];
    for (DFPeanutFeedObject *strandPosts in strands) {
      NSArray *photos = [[DFPeanutFeedDataManager sharedManager] nonEvaluatedPhotosInStrandPosts:strandPosts];
      for (DFPeanutFeedObject *photo in photos) {
        if (photo.user != [[DFUser currentUser] userID]) {
          [result addObject:photo];
        }
      }
    }
  }
  return result;
}


/* BE CAREFUL WITH THIS FUNCITON
 It does not take into account strand ID so it can leak data across strands
 */
- (DFPeanutFeedObject *)firstPhotoInAllStrandsWithId:(DFPhotoIDType)photoID
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

- (NSString *)imagePathForPhotoWithID:(DFPhotoIDType)photoID ofType:(DFImageType)type;
{
  DFPeanutFeedObject *photo = [self firstPhotoInAllStrandsWithId:photoID];
  
  if (photo) {
    if (type == DFImageFull) {
      return photo.full_image_path;
    } else {
      return photo.thumb_image_path;
    }
  } else {
    return nil;
  }
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
  NSMutableArray *inviteStrands = [NSMutableArray new];
  for (DFPeanutFeedObject *strand in self.swapsFeedObjects) {
    if ([strand.type isEqual:DFFeedObjectInviteStrand]
        && ![strand.actors containsObject:[[DFUser currentUser] peanutUser]]) {
      [inviteStrands addObject:strand];
    }
  }
  return inviteStrands;
}

- (NSArray *)acceptedStrands
{
  return [self acceptedStrandsWithPostsCollapsed:NO
                                    filterToUser:0
                               feedObjectSortKey:@"time_stamp"
                                       ascending:NO];
}

- (NSArray *)acceptedStrandsWithPostsCollapsedAndFilteredToUser:(DFUserIDType)userID
{
  return [self acceptedStrandsWithPostsCollapsed:YES
                                    filterToUser:userID
                               feedObjectSortKey:@"time_stamp"
                                       ascending:YES];
}

- (NSArray *)getStrandPostListFromStrandPosts:(DFPeanutFeedObject *)strandPosts
{
  NSMutableArray *strandPostList = [NSMutableArray new];
  for (DFPeanutFeedObject *object in strandPosts.objects) {
    if ([object.type isEqual:DFFeedObjectStrandPost]) {
      [strandPostList addObject:object];
    }
  }
  return strandPostList;
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
    collapsedObj.type = DFFeedObjectStrandPosts;
    collapsedObj.actors = [strandPosts.actors copy];
    NSMutableArray *collapsedSubObjects = [NSMutableArray new];
    for (DFPeanutFeedObject *strandPost in [self getStrandPostListFromStrandPosts:strandPosts]) {
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

- (DFPeanutUserObject *)userWithID:(DFUserIDType)userID
{
  if (userID == [[DFUser currentUser] userID]) {
    return [[DFUser currentUser] peanutUser];
  }
  for (DFPeanutFeedObject *strandPosts in self.inboxFeedObjects) {
    if (![strandPosts.type isEqual:DFFeedObjectStrandPosts]) continue;
    for (DFPeanutUserObject *actor in strandPosts.actors) {
      if (actor.id == userID) {
        return actor;
      }
    }
  }
  return nil;
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

- (NSArray *)friendsList
{
  return self.cachedFriendsList;
}

- (DFPeanutUserObject *)getUserWithId:(DFUserIDType)userID
{
  for (DFPeanutUserObject *user in self.cachedFriendsList) {
    if (user.id == userID) {
      return user;
    }
  }
  return nil;
}

- (DFPeanutUserObject *)getUserWithPhoneNumber:(NSString *)phoneNumber
{
  NSString *normalizedPhoneNumber = [DFPhoneNumberUtils normalizePhoneNumber:phoneNumber];
  for (DFPeanutUserObject *user in self.cachedFriendsList) {
    if ([user.phone_number isEqualToString:normalizedPhoneNumber]) {
      return user;
    }
  }
  return nil;
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
            toStrandID:(DFStrandIDType)strandID
               success:(DFSuccessBlock)success
               failure:(DFFailureBlock)failure
{
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.id = @(strandID);
  
  NSMutableArray *photos = [NSMutableArray new];
  for (DFPeanutFeedObject *feedObject in feedObjects) {
    if ([feedObject.type isEqual:DFFeedObjectPhoto]) {
      [photos addObject:feedObject];
    } else {
      [photos addObjectsFromArray:[feedObject descendentsOfType:DFFeedObjectPhoto]];
    }
  }
  
  NSMutableArray *photoIDs = [NSMutableArray new];
  [photoIDs addObjectsFromArray:[photos arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *photoObject) {
    return @(photoObject.id);
  }]];
  
  __weak typeof(self) weakSelf = self;
  
  [self.strandAdapter
   addPhotos:photos toStrandID:strandID success:^() {
     // cache the photos locally
     [[DFPhotoStore sharedStore] cachePhotoIDsInImageStore:photoIDs];
     [[DFPhotoStore sharedStore] markPhotosForUpload:photoIDs];
     
     [[NSNotificationCenter defaultCenter]
      postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
      object:weakSelf];
     
     if (success) success();
   } failure:^(NSError *error) {
     DDLogError(@"%@ failed to add photos to strand: %llu, error: %@",
                weakSelf.class, strandID, error);
     if (failure) failure(error);
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
                     additionalUserIds:(NSArray *)additionalUserIds
                          success:(void(^)(DFPeanutStrand *resultStrand))success
                          failure:(DFFailureBlock)failure

{
  // Create the strand
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  NSMutableArray *userIds = [NSMutableArray arrayWithObject:@([[DFUser currentUser] userID])];
  if (additionalUserIds) {
    [userIds addObjectsFromArray:additionalUserIds];
  }
  requestStrand.users = userIds;
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
     if (success) success(peanutStrand);
   } failure:^(NSError *error) {
     if (failure) failure(error);
     DDLogError(@"%@ failed to create strand: %@, error: %@",
                self.class, requestStrand, error);
   }];
}

/*
 * When we share a photo we create a new strand with just that photo and the set of users
 */
- (void)sharePhotoWithFriends:(DFPeanutFeedObject *)photo users:(NSArray *)users
{
  NSMutableArray *friendUserIds = [NSMutableArray new];
  
  for (DFPeanutUserObject *user in users) {
    [friendUserIds addObject:@(user.id)];
  }
  
  [self
   createNewStrandWithFeedObjects:[NSArray arrayWithObject:photo]
   additionalUserIds:friendUserIds
   success:^(DFPeanutStrand *resultStrand) {
     DDLogInfo(@"Successfully created new strand %@", resultStrand.id);
        }
   failure:nil
   ];
}

// Not used right now, take out if still not needed
- (NSArray *)sortedStrandPostList
{
  NSMutableArray *strandPostList = [NSMutableArray new];
  for (DFPeanutFeedObject *strandPosts in self.inboxFeedObjects) {
    [strandPostList addObjectsFromArray:[strandPosts descendentsOfType:DFFeedObjectStrandPost]];
  }
  
  NSSortDescriptor *sortDescriptor;
  sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"time_stamp"
                                               ascending:YES];
  NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
  NSArray *sortedPosts;
  sortedPosts = [strandPostList sortedArrayUsingDescriptors:sortDescriptors];
  
  return sortedPosts;
}

// This could be refactored with methods below if we keep using this method
- (NSArray *)nonEvaluatedPhotosInStrandPosts:(DFPeanutFeedObject *)strandPosts
{
  NSMutableArray *nonEvaluatedPhotos = [NSMutableArray new];
  
  NSArray *photos = [strandPosts descendentsOfType:DFFeedObjectPhoto];
  for (DFPeanutFeedObject *photo in photos) {
    BOOL photoEvaluated = NO;
    for (DFPeanutAction *action in photo.actions) {
      if (action.action_type == DFPeanutActionEvalPhoto) {
        photoEvaluated = YES;
      }
    }
    if (!photoEvaluated) {
      [nonEvaluatedPhotos addObject:photo];
    }
  }
  
  return nonEvaluatedPhotos;
}

- (NSArray *)photosWithAction:(DFActionID)actionType
{
  NSMutableArray *photosWithAction = [NSMutableArray new];
  
  for (DFPeanutFeedObject *strandPosts in [self publicStrands]) {
    for (DFPeanutFeedObject *photo in [strandPosts descendentsOfType:DFFeedObjectPhoto]) {
      BOOL photoHasAction = NO;
      for (DFPeanutAction *action in photo.actions) {
        if (action.action_type == actionType) {
          photoHasAction = YES;
        }
      }
      if (photoHasAction) {
        [photosWithAction addObject:photo];
      }
      // TODO(Derek): This should be put into a lower level.
      // Temp here to move things along
      photo.strand_id = @(strandPosts.id);
    }
  }
  
  return photosWithAction;
}

- (NSArray *)photosSortedByEvalTime:(NSArray *)photos
{
  NSArray *sortedArray;
  sortedArray = [photos sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
    DFPeanutAction *first = [(DFPeanutFeedObject*)a userEvalPhotoAction];
    DFPeanutAction *second = [(DFPeanutFeedObject*)b userEvalPhotoAction];
    
    NSDate *firstDate = first.time_stamp;
    NSDate *secondDate = second.time_stamp;
    return [secondDate compare:firstDate];
  }];
  
  return sortedArray;
}

- (NSArray *)allEvaluatedPhotos
{
  NSArray *photos = [self photosWithAction:DFPeanutActionEvalPhoto];
  return [self photosSortedByEvalTime:photos];
}

- (NSArray *)favoritedPhotos
{
  NSArray *photos = [self photosWithAction:DFPeanutActionFavorite];
  return [self photosSortedByEvalTime:photos];
}

- (void)hasEvaluatedPhoto:(DFPhotoIDType)photoID strandID:(DFStrandIDType)privateStrandID
{
  DFPeanutAction *evalAction;
  evalAction = [[DFPeanutAction alloc] init];
  evalAction.user = [[DFUser currentUser] userID];
  evalAction.action_type = DFPeanutActionEvalPhoto;
  evalAction.photo = photoID;
  evalAction.strand = privateStrandID;
  
  [self.actionAdapter addAction:evalAction success:nil failure:nil];
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

- (void)setLikedByUser:(BOOL)liked
                 photo:(DFPhotoIDType)photoID
              inStrand:(DFStrandIDType)strand
           oldActionID:(DFActionID)oldActionID
              success:(void(^)(DFActionID actionID))success
               failure:(DFFailureBlock)failure
{
  DDLogVerbose(@"Like button pressed");
  if (!liked && !oldActionID) {
    [NSException raise:@"must provide old action ID" format:@"oldActionID required when setting photo liked to false"];
  } else if (liked && oldActionID) {
    success(oldActionID);
  }
  
  DFPeanutAction *action = [[DFPeanutAction alloc] init];
  action.user = [[DFUser currentUser] userID];
  action.action_type = DFPeanutActionFavorite;
  action.photo = photoID;
  action.strand = strand;
  if (oldActionID) action.id = @(oldActionID);

  RKRequestMethod method = liked ? RKRequestMethodPOST : RKRequestMethodDELETE;
  
  [self.actionAdapter
   performRequest:method
   withPath:ActionBasePath
   objects:@[action]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     DFPeanutAction *action = resultObjects.firstObject;
     success(action.id.longLongValue);
   } failure:^(NSError *error) {
     DDLogError(@"%@ setLiked failed: %@", self.class, error);
     failure(error);
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

- (DFPeanutActionAdapter *)actionAdapter
{
  if (!_actionAdapter) _actionAdapter = [[DFPeanutActionAdapter alloc] init];
  return _actionAdapter;
}

- (DFPeanutSharedStrandAdapter *)sharedStrandAdapter
{
  if (!_sharedStrandAdapter) _sharedStrandAdapter = [[DFPeanutSharedStrandAdapter alloc] init];
  return _sharedStrandAdapter;
}

- (NSArray *)cachedFriendsList
{
  if (!_cachedFriendsList) _cachedFriendsList = [[NSArray alloc] init];
  return _cachedFriendsList;
}

@end

