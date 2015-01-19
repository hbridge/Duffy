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
#import "DFPeanutShareInstanceAdapter.h"
#import "DFUserPeanutAdapter.h"
#import "DFPeanutPhotoAdapter.h"

#define REFRESH_FEED_AFTER_SECONDS 300 //seconds between a full refresh of a feed

@interface DFPeanutFeedDataManager ()

@property (nonatomic, retain) NSArray *swapsFeedObjects;
@property (nonatomic, retain) NSArray *actionsFeedObjects;
@property (nonatomic, retain) NSArray *inboxFeedObjects;
@property (nonatomic, retain) NSArray *privateStrandsFeedObjects;

@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *swapsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *actionsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *peanutFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutActionAdapter *actionAdapter;
@property (readonly, nonatomic, retain) DFPeanutSharedStrandAdapter *sharedStrandAdapter;
@property (readonly, nonatomic, retain) DFPeanutShareInstanceAdapter *shareInstanceAdapter;
@property (readonly, nonatomic, retain) DFUserPeanutAdapter *userAdapter;

@property (atomic) BOOL swapsRefreshing;
@property (atomic) BOOL actionsRefreshing;

// Dict with keys of DFFeedType and value of NSArray * or DFPeanutFeedObjects *'s
@property (atomic, retain) NSMutableDictionary *feedObjects;

// Dict with keys of DFFeedType and value of BOOL
@property (atomic, retain) NSMutableDictionary *feedRefreshing;

// Dict with keys of DFFeedType and value of NSData *
@property (nonatomic, retain) NSMutableDictionary *feedLastResponseHash;

// Dict with keys of DFFeedType and value of NSDate *
@property (nonatomic, retain) NSMutableDictionary *feedLastFullFetchDate;

// Dict with keys of DFFeedType and value of NSString *
@property (nonatomic, retain) NSMutableDictionary *feedLastFeedTimestamp;



@property (nonatomic, retain) NSData *swapsLastResponseHash;
@property (nonatomic, retain) NSData *actionsLastResponseHash;

@property (readonly, atomic, retain) NSMutableDictionary *deferredCompletionBlocks;
@property (nonatomic) dispatch_semaphore_t deferredCompletionSchedulerSemaphore;

@property (nonatomic, retain) NSArray *cachedFriendsList;
@end

@implementation DFPeanutFeedDataManager

@synthesize cachedFriendsList = _cachedFriendsList;

@synthesize deferredCompletionBlocks = _deferredCompletionBlocks;

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
    _deferredCompletionBlocks = [NSMutableDictionary new];
    self.feedRefreshing = [NSMutableDictionary new];
    self.feedObjects = [NSMutableDictionary new];
    self.feedLastResponseHash = [NSMutableDictionary new];
    self.feedLastFullFetchDate = [NSMutableDictionary new];
    self.feedLastFeedTimestamp = [NSMutableDictionary new];
    
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
  [self refreshFeedFromServer:DFInboxFeed completion:nil];
  [self refreshFeedFromServer:DFPrivateFeed completion:nil];
  [self refreshSwapsFromServer:nil];
  [self refreshActionsFromServer:nil];
}

- (void)processInboxFeed:(NSArray *)currentObjects withNewObjects:(NSArray *)newObjects returnBlock:(void (^)(BOOL updated, NSArray *newObjects))returnBlock
{
  BOOL updated = NO;
  if (!currentObjects) {
    [self processPeopleListFromInboxObjects:newObjects];
    returnBlock(YES, newObjects);
    return;
  }
  
  NSMutableDictionary *combinedObjectsById = [NSMutableDictionary new];
  
  for (DFPeanutFeedObject *object in currentObjects) {
    [combinedObjectsById setObject:object forKey:object.share_instance];
  }
  
  for (DFPeanutFeedObject *object in newObjects) {
    DFPeanutFeedObject *existingObject = [combinedObjectsById objectForKey:object.share_instance];
    if (!existingObject || ![existingObject isEqual:object]) {
      updated = YES;
    }
    [combinedObjectsById setObject:object forKey:object.share_instance];
  }
  NSArray *newCombinedObjects = [combinedObjectsById allValues];
  
  [self processPeopleListFromInboxObjects:newCombinedObjects];
  returnBlock(updated, newCombinedObjects);
}

- (void)processPeopleListFromInboxObjects:(NSArray *)inboxFeedObjects
{
  // For inbox only, we update our local cache of friends
  // If we refactor these methods to be common this will need to be pulled out
  for (DFPeanutFeedObject *object in inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectPeopleList]) {
      NSArray *peopleList = [self processPeopleList:_cachedFriendsList withNewPeople:object.people];
      
      // This grabs the local first name which we want to sort by
      NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES];
      NSMutableArray *newFriendsList = [NSMutableArray arrayWithArray:[peopleList sortedArrayUsingDescriptors:@[sort]]];
      
      _cachedFriendsList = newFriendsList;
      if (![newFriendsList isEqualToArray:_cachedFriendsList]) {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:DFStrandNewFriendsDataNotificationName
         object:self];
        DDLogInfo(@"Got new friends data, sending notification.");
      }
    }
  }
}

- (NSArray *)processPeopleList:(NSArray *)currentPeopleList withNewPeople:(NSArray *)newPeople
{
  if (!currentPeopleList) {
    return newPeople;
  }
  
  NSMutableDictionary *combinedObjectsById = [NSMutableDictionary new];
  
  for (DFPeanutUserObject *object in currentPeopleList) {
    [combinedObjectsById setObject:object forKey:@(object.id)];
  }
  
  for (DFPeanutUserObject *object in newPeople) {
    [combinedObjectsById setObject:object forKey:@(object.id)];
  }
  
  return [combinedObjectsById allValues];
}

// TODO(Derek): This can be combine with Inbox processing above
- (void)processPrivateFeed:(NSArray *)currentObjects withNewObjects:(NSArray *)newObjects returnBlock:(void (^)(BOOL updated, NSArray *newObjects))returnBlock
{
  BOOL updated = NO;
  if (!currentObjects) {
    returnBlock(YES, newObjects);
    return;
  }
  
  NSMutableDictionary *combinedObjectsById = [NSMutableDictionary new];
  
  for (DFPeanutFeedObject *object in currentObjects) {
    [combinedObjectsById setObject:object forKey:@(object.id)];
  }
  
  for (DFPeanutFeedObject *object in newObjects) {
    DFPeanutFeedObject *existingObject = [combinedObjectsById objectForKey:@(object.id)];
    if (!existingObject || ![existingObject isEqual:object]) {
      updated = YES;
    }
    [combinedObjectsById setObject:object forKey:@(object.id)];
  }
  NSArray *newCombinedObjects = [combinedObjectsById allValues];
  
  returnBlock(updated, newCombinedObjects);
}
/* Generic feed methods */
- (void)refreshFeedFromServer:(DFFeedType)feedType completion:(RefreshCompleteCompletionBlock)completion
{
  [self refreshFeedFromServer:feedType completion:completion fullRefresh:NO];
}

- (void)refreshFeedFromServer:(DFFeedType)feedType completion:(RefreshCompleteCompletionBlock)completion fullRefresh:(BOOL)fullRefresh
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  if (completion) [self scheduleDeferredCompletion:completion forFeedType:feedType];
  
  if (![[self.feedRefreshing objectForKey:@(feedType)] boolValue]) {
    [self.feedRefreshing setObject:[NSNumber numberWithBool:YES] forKey:@(feedType)];
    
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    if ([self.feedLastFeedTimestamp objectForKey:@(feedType)] && !fullRefresh) {
      [parameters setObject:[self.feedLastFeedTimestamp objectForKey:@(feedType)] forKey:@"last_timestamp"];
    } else if (![self.feedLastFeedTimestamp objectForKey:@(feedType)] && !fullRefresh) {
      // If we don't have a last timestamp then we're doing a cold start.
      // This fetch, grab just 20 elements, but also kick off a full refresh after this first one comes back
      [parameters setObject:@(20) forKey:@"num"];
    }
    
    [self fetchFeedOfType:feedType withCompletion:^(DFPeanutObjectsResponse *response,
                                                    NSData *responseHash,
                                                    NSError *error) {
      [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
      
      if (!error) {
        // If we're not doing a full refresh, then check to see if we should do one.
        // Either if we haven't done one before or its been longer than 5 minutes
        if (!fullRefresh) {
          if (![self.feedLastFullFetchDate objectForKey:@(feedType)] || [[NSDate date] timeIntervalSinceDate:[self.feedLastFullFetchDate objectForKey:@(feedType)]] > REFRESH_FEED_AFTER_SECONDS) {
            dispatch_async(dispatch_get_main_queue(), ^{
              [self refreshFeedFromServer:feedType completion:completion fullRefresh:YES];
            });
          }
        }
        
        if (response.timestamp) {
          [self.feedLastFeedTimestamp setObject:response.timestamp forKey:@(feedType)];
        }
        
        [self processFeedOfType:feedType currentObjects:[self.feedObjects objectForKey:@(feedType)] withNewObjects:response.objects returnBlock:^(BOOL updated, NSArray *newObjects) {
          [self.feedObjects setObject:newObjects forKey:@(feedType)];
          if (updated) {
            [self notifyFeedChanged:feedType];
            DDLogInfo(@"Got new data for feed %@ with %d objects, sending notification.", @(feedType), (int)newObjects.count);
          }
        }];
        
        if (fullRefresh) {
          [self.feedLastFullFetchDate setObject:[NSDate date] forKey:@(feedType)];
          [self.feedLastResponseHash setObject:responseHash forKey:@(feedType)];
        }
      }
      
      [self executeDeferredCompletionsForFeedType:feedType];
      [self.feedRefreshing setObject:[NSNumber numberWithBool:NO] forKey:@(feedType)];
    }
               parameters:parameters
     ];
  }
}

- (void)fetchFeedOfType:(DFFeedType)feedType withCompletion:(DFPeanutObjectsCompletion)completion parameters:(NSDictionary *)parameters
{
  if (feedType == DFInboxFeed) {
    [self.peanutFeedAdapter fetchInboxWithCompletion:completion parameters:parameters];
  } else if (feedType == DFPrivateFeed) {
    [self.peanutFeedAdapter fetchAllPrivateStrandsWithCompletion:completion parameters:parameters];
  }
}

- (void)processFeedOfType:(DFFeedType)feedType currentObjects:(NSArray *)currentObjects withNewObjects:(NSArray *)newObjects returnBlock:(void (^)(BOOL updated, NSArray *newObjects))returnBlock
{
  if (feedType == DFInboxFeed) {
    [self processInboxFeed:currentObjects withNewObjects:newObjects returnBlock:returnBlock];
  } else if (feedType == DFPrivateFeed) {
    [self processPrivateFeed:currentObjects withNewObjects:newObjects returnBlock:returnBlock];
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
  return ([self.feedLastFeedTimestamp objectForKey:@(DFInboxFeed)] != nil);
}

- (BOOL)hasPrivateStrandData
{
  return ([self.feedLastFeedTimestamp objectForKey:@(DFPrivateFeed)] != nil);
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


- (NSArray *)photosWithUserID:(DFUserIDType)userID onlyEvaluated:(BOOL)onlyEvaluated
{
  NSMutableArray *photos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *photo in self.inboxFeedObjects) {
    if (onlyEvaluated && !photo.evaluated.boolValue) continue;
    if ([photo.actor_ids containsObject:@(userID)]) [photos addObject:photo];
  }
  
  return [self sortedPhotos:photos];
}

- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user
{
  NSMutableArray *strands = [NSMutableArray new];

  for (DFPeanutFeedObject *object in self.privateStrandsFeedObjects) {
    if (!object.suggestible.boolValue) continue;
    if ([object.actor_ids containsObject:@(user.id)]) [strands addObject:object];
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

- (DFPeanutFeedObject *)photoWithID:(DFPhotoIDType)photoID
                      shareInstance:(DFStrandIDType)shareInstance
{
  for (DFPeanutFeedObject *photo in self.inboxFeedObjects) {
    if (photo.id == photoID && photo.share_instance.longLongValue == shareInstance) {
      return photo;
    }
  }
  
  return nil;
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
            if (obj1.sort_rank && !obj2.sort_rank) {
              return NSOrderedAscending;
            } else if (obj2.sort_rank && !obj2.sort_rank) {
              return NSOrderedDescending;
            } else {
              return [obj1.sort_rank compare:obj2.sort_rank];
            }
  }];
}


- (NSArray *)photosFromSuggestedStrands
{
  NSArray *suggestedStrands = [self suggestedStrands];
  NSMutableArray *allPhotos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *strand in suggestedStrands) {
    [allPhotos addObjectsFromArray:[strand leafNodesFromObjectOfType:DFFeedObjectPhoto]];
  }
  NSPredicate *predicate = [NSPredicate
                            predicateWithFormat:@"evaluated == nil"];

  return [allPhotos filteredArrayUsingPredicate:predicate];
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
  return [[self.feedRefreshing objectForKey:@(DFInboxFeed)] boolValue];
}

- (NSArray *)friendsList
{
  NSMutableArray *friends = [NSMutableArray new];
  for (DFPeanutUserObject *user in self.cachedFriendsList) {
    if ([user.relationship isEqual:DFPeanutUserRelationshipFriend]) [friends addObject:user];
  }
  return friends;
}

- (DFPeanutUserObject *)userWithID:(DFUserIDType)userID
{
  if (userID == [[DFUser currentUser] userID]) return [[DFUser currentUser] peanutUser];
  for (DFPeanutUserObject *user in self.cachedFriendsList) {
    if (user.id == userID) {
      return user;
    }
  }
  return nil;
}

- (DFPeanutUserObject *)userWithPhoneNumber:(NSString *)phoneNumber
{
  NSString *normalizedPhoneNumber = [DFPhoneNumberUtils normalizePhoneNumber:phoneNumber];
  for (DFPeanutUserObject *user in self.cachedFriendsList) {
    if ([user.phone_number isEqualToString:normalizedPhoneNumber]) {
      return user;
    }
  }
  return nil;
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

- (void)sharePhotoObjects:(NSArray *)photoObjects
              withPhoneNumbers:(NSArray *)phoneNumbers
                  success:(void(^)(NSArray *shareInstances, NSArray *createdPhoneNumbers))success
                  failure:(DFFailureBlock)failure
{
  // Get UIDs
  
  [self
   userIDsFromPhoneNumbers:phoneNumbers
   success:^(NSDictionary *phoneNumbersToUserIDs, NSArray *createdUserPhoneNumbers) {
    // Create the strand
    NSMutableArray *shareInstances = [NSMutableArray new];
    for (DFPeanutFeedObject *photo in photoObjects) {
      DFPeanutShareInstance *shareInstance = [DFPeanutShareInstance new];
      shareInstance.photo = @(photo.id);
      NSMutableSet *users = [[NSMutableSet alloc] initWithArray:phoneNumbersToUserIDs.allValues];
      [users addObject:@([[DFUser currentUser] userID])];
      shareInstance.users = users.allObjects;
      shareInstance.user = @([[DFUser currentUser] userID]);
      [shareInstances addObject:shareInstance];
    }
    
    [self.shareInstanceAdapter
     createShareInstances:shareInstances
     success:^(NSArray *resultObjects) {
       DDLogInfo(@"%@ successfully create share instances: %@", self.class, resultObjects);
       [[NSNotificationCenter defaultCenter]
        postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
        object:self];
       
       // start uploading the photos
       NSArray *photoIDs = [photoObjects arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *photo) {
         return @(photo.id);
       }];
       [[DFPhotoStore sharedStore] markPhotosForUpload:photoIDs];
       [[DFPhotoStore sharedStore] cachePhotoIDsInImageStore:photoIDs];
       success(resultObjects, createdUserPhoneNumbers);
     } failure:^(NSError *error) {
       failure(error);
     }];

     for (DFPeanutFeedObject *photo in photoObjects) {
       [self setLocalHasEvaluatedPhoto:photo.id shareInstance:0];
     }
     
  } failure:^(NSError *error) {
    failure(error);
  }];
}

- (void)userIDsFromPhoneNumbers:(NSArray *)phoneNumbers
                        success:(void(^)(NSDictionary *phoneNumbersToUserIDs, NSArray *createdUserPhoneNumbers))success
                        failure:(DFFailureBlock)failure
{
  NSMutableDictionary *phoneNumbersToUserIDs = [NSMutableDictionary new];
  NSMutableArray *phoneNumbersToCreateUser = [NSMutableArray new];
  for (NSString *phoneNumber in  phoneNumbers) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager]
                                userWithPhoneNumber:phoneNumber];
    if (user) {
      phoneNumbersToUserIDs[phoneNumber] = @(user.id);
    } else {
      [phoneNumbersToCreateUser addObject:phoneNumber];
    }
  }
  
  if (phoneNumbersToCreateUser.count > 0) {
    [self.userAdapter
     createUsersForPhoneNumbers:phoneNumbers
     withSuccessBlock:^(NSArray *resultObjects) {
       DDLogVerbose(@"added users %@", resultObjects);
       for (DFPeanutUserObject *user in resultObjects) {
         if (user.id != 0)
           phoneNumbersToUserIDs[user.phone_number] = @(user.id);
       }
       success(phoneNumbersToUserIDs, phoneNumbersToCreateUser);
    } failureBlock:^(NSError *error) {
      failure(error);
    }];
  } else {
    success(phoneNumbersToUserIDs, nil);
  }
}


- (void)addUsersWithPhoneNumbers:(NSArray *)phoneNumbers
               toShareInstanceID:(DFShareInstanceIDType)shareInstanceID
                         success:(void(^)(NSArray *numbersToText))success
                         failure:(DFFailureBlock)failure
{
  [self
   userIDsFromPhoneNumbers:phoneNumbers
   success:^(NSDictionary *phoneNumbersToUserIDs, NSArray *createdUserPhoneNumbers) {
     [self.shareInstanceAdapter
      addUserIDs:phoneNumbersToUserIDs.allValues
      toShareInstanceID:shareInstanceID
      success:^(NSArray *resultObjects) {
        success(createdUserPhoneNumbers);
      } failure:^(NSError *error) {
        failure(error);
      }];
     
     
   } failure:^(NSError *error) {
     failure(error);
   }];
}

- (NSArray *)allPhotos
{
  return [self sortedPhotos:[DFPeanutFeedObject leafObjectsOfType:DFFeedObjectPhoto
                                             inArrayOfFeedObjects:self.inboxFeedObjects]];
}

- (NSArray *)photosWithAction:(DFActionID)actionType
{
  NSMutableArray *photosWithAction = [NSMutableArray new];
  
  for (DFPeanutFeedObject *photo in self.inboxFeedObjects) {
    BOOL photoHasAction = NO;
    for (DFPeanutAction *action in photo.actions) {
      if (action.action_type == actionType) {
        photoHasAction = YES;
      }
    }
    if (photoHasAction) {
      [photosWithAction addObject:photo];
    }
  }
  
  return photosWithAction;
}

- (NSArray *)evaluatedPhotos
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFPeanutFeedObject *photo in self.inboxFeedObjects) {
    if (photo.evaluated.boolValue) [result addObject:photo];
  }
  return result;
}

- (NSArray *)photosSentByUser:(DFUserIDType)user
{
  NSMutableArray *photosSentByUser = [NSMutableArray new];
  
  for (DFPeanutFeedObject *photo in self.inboxFeedObjects) {
      if (photo.user == user) {
        [photosSentByUser addObject:photo];
      }
  }
  
  return photosSentByUser;
}

- (NSArray *)sortedPhotos:(NSArray *)photos
{
  NSArray *sortedArray;
  sortedArray = [photos sortedArrayUsingComparator:^NSComparisonResult(DFPeanutFeedObject *a, DFPeanutFeedObject *b) {
    return [a.sort_rank compare:b.sort_rank];
  }];
  
  return sortedArray;
}

- (NSArray *)allEvaluatedOrSentPhotos
{
  NSArray *evaledPhotos = [self evaluatedPhotos];
  NSArray *myPhotos = [self photosSentByUser:[[DFUser currentUser] userID]];
  NSMutableSet *merged = [[NSMutableSet alloc] initWithCapacity:evaledPhotos.count + myPhotos.count];
  [merged addObjectsFromArray:evaledPhotos];
  [merged addObjectsFromArray:myPhotos];
  return [self sortedPhotos:merged.allObjects];
}

- (NSArray *)favoritedPhotos
{
  NSArray *photos = [self photosWithAction:DFPeanutActionFavorite];
  return [self sortedPhotos:photos];
}

- (NSArray *)photosWithActivity
{
  NSArray *likedPhotos = [self photosWithAction:DFPeanutActionFavorite];
  NSArray *commentedPhotos = [self photosWithAction:DFPeanutActionComment];
  NSMutableSet *merged = [[NSMutableSet alloc] initWithArray:likedPhotos];
  [merged addObjectsFromArray:commentedPhotos];
  NSSet *evaledPhotos = [[NSSet alloc] initWithArray:[self allEvaluatedOrSentPhotos]];
  [merged intersectSet:evaledPhotos];
  return [self sortedPhotos:merged.allObjects];
}

- (void)setHasEvaluatedPhoto:(DFPhotoIDType)photoID shareInstance:(DFStrandIDType)shareInstance
{
  DFPeanutAction *evalAction;
  evalAction = [[DFPeanutAction alloc] init];
  evalAction.user = [[DFUser currentUser] userID];
  evalAction.action_type = DFPeanutActionEvalPhoto;
  evalAction.photo = @(photoID);
  if (shareInstance) {
    evalAction.share_instance = @(shareInstance);
  }
  
  // Make a call to the backend but also update our local cache.
  [self.actionAdapter addAction:evalAction success:nil failure:nil];
  [self setLocalHasEvaluatedPhoto:photoID shareInstance:shareInstance];
}

- (void)setLocalHasEvaluatedPhoto:(DFPhotoIDType)photoID shareInstance:(DFStrandIDType)shareInstance
{
  for (DFPeanutFeedObject *object in self.inboxFeedObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto] && object.id == photoID && [object.share_instance isEqual:@(shareInstance)]) {
      object.evaluated = @(1);
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandNewInboxDataNotificationName
       object:self];
    }
  }
  for (DFPeanutFeedObject *photo in [self photosFromSuggestedStrands]) {
    if (photo.id == photoID) {
      photo.evaluated = @(1);
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandNewSwapsDataNotificationName
       object:self];
    }
  }
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
              shareInstance:(DFStrandIDType)shareInstance
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
  action.photo = @(photoID);
  action.share_instance = @(shareInstance);
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

- (void)addComment:(NSString *)comment
         toPhotoID:(DFPhotoIDType)photoID
     shareInstance:(DFShareInstanceIDType)shareInstance
           success:(void(^)(DFActionID actionID))success
           failure:(DFFailureBlock)failure
{
  DFPeanutAction *action = [[DFPeanutAction alloc] init];
  action.user = [[DFUser currentUser] userID];
  action.action_type = DFPeanutActionComment;
  action.text = comment;
  action.photo = @(photoID);
  action.share_instance = @(shareInstance);
  action.time_stamp = [NSDate date];
  
  [self.actionAdapter addAction:action success:^(NSArray *resultObjects) {
    DDLogError(@"%@ added comment: %@", [DFPeanutFeedDataManager class], resultObjects.firstObject);
    DFPeanutAction *newComment = [resultObjects firstObject];
    success(newComment.id.longLongValue);
  } failure:^(NSError *error) {
    DDLogError(@"%@ adding comment error:%@", [DFPeanutFeedDataManager class], error);
  }];
}


- (void)deleteShareInstance:(DFShareInstanceIDType)shareInstanceID
                    success:(DFVoidBlock)success
                    failure:(DFFailureBlock)failure;
{
  DFPeanutShareInstance *shareInstance = [[DFPeanutShareInstance alloc] init];
  shareInstance.id = @(shareInstanceID);
  [self.shareInstanceAdapter
   deleteShareInstance:shareInstance
   success:^(NSArray *resultObjects) {
     self.inboxFeedObjects = [self.inboxFeedObjects
                              objectsPassingTestBlock:^BOOL(DFPeanutFeedObject *feedObject) {
                                if (feedObject.share_instance.longLongValue == shareInstanceID) {
                                  return NO;
                                }
                                return YES;
                              }];
     [self notifyFeedChanged:DFInboxFeed];
     success();
   } failure:^(NSError *error) {
     failure(error);
   }];
}

#pragma mark - Notify of feed changes

- (void)notifyFeedChanged:(DFFeedType)feedType
{
  [[NSNotificationCenter defaultCenter]
   postNotificationName:[self notificationNameForFeed:feedType]
   object:self];
}

static NSDictionary *nameMapping;
- (NSString *)notificationNameForFeed:(DFFeedType)feedType
{
  if (!nameMapping) nameMapping = @{
    @(DFInboxFeed) : DFStrandNewInboxDataNotificationName,
    @(DFPrivateFeed) : DFStrandNewPrivatePhotosDataNotificationName,
  };
  return nameMapping[@(feedType)];
}


#pragma mark - Network Adapters

@synthesize swapsFeedAdapter = _swapsFeedAdapter;
@synthesize actionsFeedAdapter = _actionsFeedAdapter;
@synthesize peanutFeedAdapter = _peanutFeedAdapter;

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize actionAdapter = _actionAdapter;
@synthesize sharedStrandAdapter = _sharedStrandAdapter;
@synthesize shareInstanceAdapter = _shareInstanceAdapter;
@synthesize userAdapter = _userAdapter;

@synthesize inboxFeedObjects = _inboxFeedObjects;
@synthesize privateStrandsFeedObjects = _privateStrandsFeedObjects;

- (NSArray *)inboxFeedObjects
{
  return [self.feedObjects objectForKey:@(DFInboxFeed)];
}

- (void)setInboxFeedObjects:(NSArray *)inboxFeedObjects
{
  self.feedObjects[@(DFInboxFeed)] = inboxFeedObjects;
}

- (NSArray *)privateStrandsFeedObjects
{
  return [self.feedObjects objectForKey:@(DFPrivateFeed)];
}

- (DFPeanutFeedAdapter *)peanutFeedAdapter
{
  if (!_peanutFeedAdapter) _peanutFeedAdapter = [[DFPeanutFeedAdapter alloc] init];
  return _peanutFeedAdapter;
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

- (DFPeanutShareInstanceAdapter *)shareInstanceAdapter
{
  if (!_shareInstanceAdapter) _shareInstanceAdapter = [DFPeanutShareInstanceAdapter new];
  return _shareInstanceAdapter;
}

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) _userAdapter = [DFUserPeanutAdapter new];
  return _userAdapter;
}

- (NSArray *)cachedFriendsList
{
  if (!_cachedFriendsList) _cachedFriendsList = [[NSArray alloc] init];
  return _cachedFriendsList;
}

- (void)resetManager
{
  DDLogInfo(@"%@ resetting manager.", self.class);
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  defaultManager = nil;
}

@end

