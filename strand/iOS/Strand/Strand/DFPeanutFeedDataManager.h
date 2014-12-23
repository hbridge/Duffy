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

- (NSArray *)privateStrands;
- (NSArray *)privatePhotos;
- (NSArray *)privateStrandsByDateAscending:(BOOL)ascending;
- (NSArray *)remotePhotos;
- (NSArray *)suggestedStrands;
- (NSArray *)photosWithUserID:(DFUserIDType)userID evaluated:(BOOL)evaluated;
- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user;
- (NSArray *)actionsList;
- (NSArray *)actionsListFilterUser:(DFPeanutUserObject *)user;

- (NSArray *)unevaluatedPhotosFromOtherUsers;
- (NSArray *)allEvaluatedOrSentPhotos;
- (NSArray *)favoritedPhotos;
- (NSArray *)photosWithActivity;

- (DFPeanutFeedObject *)photoWithID:(DFPhotoIDType)photoID shareInstance:(DFStrandIDType)shareInstance;
- (NSArray *)photosSentByUser:(DFUserIDType)user;

- (NSString *)imagePathForPhotoWithID:(DFPhotoIDType)photoID ofType:(DFImageType)type;

// Methods used for dealing with swap page
- (void)setHasEvaluatedPhoto:(DFPhotoIDType)photoID shareInstance:(DFShareInstanceIDType)privateStrandID;
- (void)sharePhotoWithFriends:(DFPeanutFeedObject *)photo users:(NSArray *)users;

/* returns a list of PeanutUsers */
- (NSArray *)friendsList;
- (DFPeanutUserObject *)userWithID:(DFUserIDType)userID;
- (DFPeanutUserObject *)userWithPhoneNumber:(NSString *)phoneNumber;

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
         shareInstance:(DFStrandIDType)shareInstance
           oldActionID:(DFActionID)oldActionID
               success:(void(^)(DFActionID actionID))success
               failure:(DFFailureBlock)failure;
@end
