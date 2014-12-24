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

@interface DFPeanutFeedDataManager ()

@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *inboxFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *privateStrandsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *swapsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutFeedAdapter *actionsFeedAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutActionAdapter *actionAdapter;
@property (readonly, nonatomic, retain) DFPeanutSharedStrandAdapter *sharedStrandAdapter;
@property (readonly, nonatomic, retain) DFPeanutShareInstanceAdapter *shareInstanceAdapter;


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
             _cachedFriendsList = [NSMutableArray arrayWithArray:[object.friends sortedArrayUsingDescriptors:@[sort]]];
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


- (NSArray *)photosWithUserID:(DFUserIDType)userID evaluated:(BOOL)evaluated
{
  NSMutableArray *photos = [NSMutableArray new];
  
  for (DFPeanutFeedObject *photo in self.inboxFeedObjects) {
    for (NSUInteger i = 0; i < photo.actors.count; i++) {
      NSNumber *actorID = photo.actors[i];
      if (userID == actorID.longLongValue && photo.evaluated.boolValue == evaluated) {
        [photos addObject:photo];
      }
    }
  }
  
  return photos;
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

- (NSArray *)unevaluatedPhotosFromOtherUsers
{
  NSMutableOrderedSet *result = [NSMutableOrderedSet new];
  for (DFPeanutUserObject *user in self.friendsList) {
    NSArray *photos = [[DFPeanutFeedDataManager sharedManager] photosWithUserID:user.id evaluated:NO];
    for (DFPeanutFeedObject *photoObject in photos) {
      if (photoObject.evaluated.boolValue == NO && photoObject.user != [[DFUser currentUser] userID]) {
        [result addObject:photoObject];
      }
    }
  }
  return [result array];
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
            if (obj1.suggestion_rank && !obj2.suggestion_rank) {
              return NSOrderedAscending;
            } else if (obj2.suggestion_rank && !obj2.suggestion_rank) {
              return NSOrderedDescending;
            } else {
              return [obj1.suggestion_rank compare:obj2.suggestion_rank];
            }
  }];
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
                  success:(void(^)(NSArray *photos, NSArray *createdPhoneNumbers))success
                  failure:(DFFailureBlock)failure
{
  // Get UIDs
  
  [self userIDsFromPhoneNumbers:phoneNumbers success:^(NSArray *userIDs, NSArray *createdUserPhoneNumbers) {
    // Create the strand
    NSMutableArray *shareInstances = [NSMutableArray new];
    for (DFPeanutFeedObject *photo in photoObjects) {
      DFPeanutShareInstance *shareInstance = [DFPeanutShareInstance new];
      shareInstance.photo = @(photo.id);
      NSMutableSet *users = [[NSMutableSet alloc] initWithArray:userIDs];
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

  } failure:^(NSError *error) {
    failure(error);
  }];
}

- (void)userIDsFromPhoneNumbers:(NSArray *)phoneNumbers
                        success:(void(^)(NSArray *userIDs, NSArray *createdUserPhoneNumbers))success
                        failure:(DFFailureBlock)failure
{
  NSMutableArray *userIDs = [NSMutableArray new];
  NSMutableArray *phoneNumbersToCreateUser = [NSMutableArray new];
  for (NSString *phoneNumber in  phoneNumbers) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager]
                                userWithPhoneNumber:phoneNumber];
    if (user) {
      [userIDs addObject:@(user.id)];
    } else {
      [phoneNumbersToCreateUser addObject:phoneNumber];
    }
  }
  
  if (phoneNumbersToCreateUser.count > 0) {
    // create users
    
    
  } else {
    success(userIDs, nil);
  }
}


- (void)addUsersWithPhoneNumbers:(NSArray *)phoneNumbers
 toShareInstanceID:(DFShareInstanceIDType)shareInstanceID
           success:(void(^)(NSArray *numbersToText))success
           failure:(DFFailureBlock)failure
{
  [self userIDsFromPhoneNumbers:phoneNumbers success:^(NSArray *userIDs, NSArray *createdUserPhoneNumbers) {
    [self.shareInstanceAdapter addUserIDs:userIDs
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
    } else if (actionType == DFPeanutActionEvalPhoto && photo.evaluated) {
      [photosWithAction addObject:photo];
    }
  }
  
  return photosWithAction;
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

- (NSArray *)photosSortedByEvalTime:(NSArray *)photos
{
  NSArray *sortedArray;
  sortedArray = [photos sortedArrayUsingComparator:^NSComparisonResult(DFPeanutFeedObject *a, DFPeanutFeedObject *b) {
    NSDate *dateA = a.evaluated_time ? a.evaluated_time : a.shared_at_timestamp;
    NSDate *dateB = b.evaluated_time ? b.evaluated_time : b.shared_at_timestamp;
    return [dateB compare:dateA];
  }];
  
  return sortedArray;
}

- (NSArray *)allEvaluatedOrSentPhotos
{
  NSArray *evaledPhotos = [self photosWithAction:DFPeanutActionEvalPhoto];
  NSArray *myPhotos = [self photosSentByUser:[[DFUser currentUser] userID]];
  NSMutableSet *merged = [[NSMutableSet alloc] initWithCapacity:evaledPhotos.count + myPhotos.count];
  [merged addObjectsFromArray:evaledPhotos];
  [merged addObjectsFromArray:myPhotos];
  return [self photosSortedByEvalTime:merged.allObjects];
}

- (NSArray *)favoritedPhotos
{
  NSArray *photos = [self photosWithAction:DFPeanutActionFavorite];
  return [self photosSortedByEvalTime:photos];
}

- (NSArray *)photosWithActivity
{
  NSArray *likedPhotos = [self photosWithAction:DFPeanutActionFavorite];
  NSArray *commentedPhotos = [self photosWithAction:DFPeanutActionComment];
  NSMutableSet *merged = [[NSMutableSet alloc] initWithArray:likedPhotos];
  [merged addObjectsFromArray:commentedPhotos];
  NSSet *evaledPhotos = [[NSSet alloc] initWithArray:[self allEvaluatedOrSentPhotos]];
  [merged intersectSet:evaledPhotos];
  return [self photosSortedByEvalTime:merged.allObjects];
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
  
  [self.actionAdapter addAction:evalAction success:nil failure:nil];
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




#pragma mark - Network Adapters

@synthesize inboxFeedAdapter = _inboxFeedAdapter;
@synthesize swapsFeedAdapter = _swapsFeedAdapter;
@synthesize privateStrandsFeedAdapter = _privateStrandsFeedAdapter;
@synthesize actionsFeedAdapter = _actionsFeedAdapter;
@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize actionAdapter = _actionAdapter;
@synthesize sharedStrandAdapter = _sharedStrandAdapter;
@synthesize shareInstanceAdapter = _shareInstanceAdapter;

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

- (DFPeanutShareInstanceAdapter *)shareInstanceAdapter
{
  if (!_shareInstanceAdapter) _shareInstanceAdapter = [DFPeanutShareInstanceAdapter new];
  return _shareInstanceAdapter;
}

- (NSArray *)cachedFriendsList
{
  if (!_cachedFriendsList) _cachedFriendsList = [[NSArray alloc] init];
  return _cachedFriendsList;
}

@end

