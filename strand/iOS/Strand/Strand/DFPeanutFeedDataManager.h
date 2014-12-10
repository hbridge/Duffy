//
//  DFInboxDataManager.h
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutUserObject.h"
#import "DFPeanutFeedObject.h"
#import <MessageUI/MessageUI.h>
#import "DFPeanutStrand.h"

@interface DFPeanutFeedDataManager : NSObject

typedef void (^RefreshCompleteCompletionBlock)(void);

+ (DFPeanutFeedDataManager *)sharedManager;

- (void)refreshInboxFromServer:(RefreshCompleteCompletionBlock)completion;
- (void)refreshPrivatePhotosFromServer:(RefreshCompleteCompletionBlock)completion;
- (void)refreshSwapsFromServer:(RefreshCompleteCompletionBlock)completion;
- (void)refreshActionsFromServer:(RefreshCompleteCompletionBlock)completion;

- (BOOL)hasInboxData;
- (BOOL)hasPrivateStrandData;
- (BOOL)hasSwapsData;
- (BOOL)areSuggestionsReady;
- (BOOL)hasActionsData;

- (BOOL)isRefreshingInbox;

- (NSArray *)publicStrands;
- (NSArray *)inviteStrands;
- (NSArray *)acceptedStrands;
- (NSArray *)acceptedStrandsWithPostsCollapsedAndFilteredToUser:(DFUserIDType)userID;
- (NSArray *)privateStrands;
- (NSArray *)privatePhotos;
- (NSArray *)privateStrandsByDateAscending:(BOOL)ascending;
- (NSArray *)remotePhotos;
- (NSArray *)suggestedStrands;
- (NSArray *)publicStrandsWithUser:(DFPeanutUserObject *)user includeInvites:(BOOL)includeInvites;
- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user;
- (NSArray *)actionsList;
- (NSArray *)actionsListFilterUser:(DFPeanutUserObject *)user;

- (NSArray *)getStrandPostListFromStrandPosts:(DFPeanutFeedObject *)strandPosts;

- (NSArray *)nonEvaluatedPhotosInStrandPosts:(DFPeanutFeedObject *)strandPosts;
- (NSArray *)unevaluatedPhotosFromOtherUsers;
- (NSArray *)allEvaluatedPhotos;
- (NSArray *)favoritedPhotos;

- (DFPeanutFeedObject *)strandPostsObjectWithId:(DFStrandIDType)strandPostsId;
- (DFPeanutFeedObject *)photoWithID:(DFPhotoIDType)photoID inStrand:(DFStrandIDType)strandID;

- (DFPeanutFeedObject *)inviteObjectWithId:(DFInviteIDType)inviteId;
- (NSString *)imagePathForPhotoWithID:(DFPhotoIDType)photoID ofType:(DFImageType)type;

// Methods used for dealing with swap page
- (void)hasEvaluatedPhoto:(DFPhotoIDType)photoID strandID:(DFStrandIDType)privateStrandID;
- (void)sharePhotoWithFriends:(DFPeanutFeedObject *)photo users:(NSArray *)users;

/* returns a list of PeanutUsers */
- (NSArray *)friendsList;
- (DFPeanutUserObject *)userWithID:(DFUserIDType)userID;
- (DFPeanutUserObject *)getUserWithPhoneNumber:(NSString *)phoneNumber;


- (void)acceptInvite:(DFPeanutFeedObject *)inviteFeedObject
         addPhotoIDs:(NSArray *)photoIDs
             success:(void(^)(void))success
             failure:(void(^)(NSError *error))failure;

- (void)addFeedObjects:(NSArray *)feedObjects
            toStrandID:(DFStrandIDType)strandID
               success:(DFSuccessBlock)success
               failure:(DFFailureBlock)failure;

- (void)markSuggestion:(DFPeanutFeedObject *)suggestedSection visible:(BOOL)visible;


- (void)createNewStrandWithFeedObjects:(NSArray *)feedObjects
                     additionalUserIds:(NSArray *)additionalUserIds
                               success:(void(^)(DFPeanutStrand *resultStrand))success
                               failure:(DFFailureBlock)failure;

- (void)removePhoto:(DFPeanutFeedObject *)photoObject
    fromStrandPosts:(DFPeanutFeedObject *)strandPosts
            success:(DFSuccessBlock)success
            failure:(DFFailureBlock)failure;


- (void)setLikedByUser:(BOOL)liked
                 photo:(DFPhotoIDType)photoID
              inStrand:(DFStrandIDType)strand
           oldActionID:(DFActionID)oldActionID
               success:(void(^)(DFActionID actionID))success
               failure:(DFFailureBlock)failure;
@end
