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

- (void)refreshFeedFromServer:(DFFeedType)feedType completion:(RefreshCompleteCompletionBlock)completion;
- (void)refreshUsersFromServerWithCompletion:(RefreshCompleteCompletionBlock)completion;
- (void)refreshAllFeedsFromServer;

- (BOOL)hasInboxData;
- (BOOL)hasPrivateStrandData;
- (BOOL)hasSwapsData;
- (BOOL)hasActionsData;

- (NSArray *)privateStrands;
- (NSArray *)privatePhotos;
- (NSArray *)privateStrandsByDateAscending:(BOOL)ascending;
- (NSArray *)remotePhotos;
- (NSArray *)suggestedStrands;
- (DFPeanutFeedObject *)suggestedStrandWithID:(DFStrandIDType)strandID;
- (void)suggestedStrandWithID:(DFStrandIDType)strandID
                   completion:(void (^)(DFPeanutFeedObject *suggestedStrand))completion;
- (DFPeanutFeedObject *)suggestedStrandForSuggestedPhoto:(DFPeanutFeedObject *)suggestedPhoto;
- (NSArray *)suggestedPhotosIncludeEvaled:(BOOL)includeEvaled;
- (NSArray *)photosWithUserID:(DFUserIDType)userID onlyEvaluated:(BOOL)evaluated;
- (NSArray *)photosWithEvaluated:(BOOL)evaluated;
- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user;
- (NSArray *)actionsList;
- (NSArray *)actionsListFilterUser:(DFPeanutUserObject *)user;

- (NSArray *)allPhotos;
- (NSArray *)allEvaluatedOrSentPhotos;
- (NSArray *)favoritedPhotos;
- (NSArray *)photosWithActivity;

- (DFPeanutFeedObject *)photoWithID:(DFPhotoIDType)photoID shareInstance:(DFStrandIDType)shareInstance;
- (NSArray *)photosSentByUser:(DFUserIDType)user;

- (NSString *)imagePathForPhotoWithID:(DFPhotoIDType)photoID ofType:(DFImageType)type;

// Methods used for dealing with swap page
- (void)setHasEvaluatedPhoto:(DFPhotoIDType)photoID shareInstance:(DFShareInstanceIDType)privateStrandID;

/* 
 User Management
 */

- (NSArray *)friendsList;
- (BOOL)isUserFriend:(DFUserIDType)userID;
- (NSArray *)usersThatFriendedUser:(DFUserIDType)user excludeFriends:(BOOL)excludeFriends;
- (void)setUser:(DFUserIDType)user
      isFriends:(BOOL)isFriends
    withUserIDs:(NSArray *)otherUserIDs
        success:(DFSuccessBlock)success
        failure:(DFFailureBlock)failure;

/* User lookup */
- (DFPeanutUserObject *)userWithID:(DFUserIDType)userID;
- (DFPeanutUserObject *)userWithPhoneNumber:(NSString *)phoneNumber;
- (void)fetchUserWithPhoneNumber:(NSString *)phoneNumber
                         success:(void (^)(DFPeanutUserObject *resultUser))success
                         failure:(DFFailureBlock)failure;
/* Maps phone numbers to userIDs, creating UIDs for any phone numbers not already created */
- (void)userIDsFromPhoneNumbers:(NSArray *)phoneNumbers
                        success:(void(^)(NSDictionary *phoneNumbersToUserIDs, NSArray *unAuthedPhoneNumbers))success
                        failure:(DFFailureBlock)failure;
/* 
 Suggestions and Photos
 */
- (void)sharePhotoObjects:(NSArray *)photoObjects
     withPhoneNumbers:(NSArray *)phoneNumbers
              success:(void(^)(NSArray *shareInstances, NSArray *createdPhoneNumbers))success
              failure:(DFFailureBlock)failure;

- (void)addUsersWithPhoneNumbers:(NSArray *)phoneNumbers
               toShareInstanceID:(DFShareInstanceIDType)shareInstanceID
                         success:(void(^)(NSArray *numbersToText))success
                         failure:(DFFailureBlock)failure;

- (void)setLikedByUser:(BOOL)liked
                 photo:(DFPhotoIDType)photoID
         shareInstance:(DFShareInstanceIDType)shareInstance
               success:(void(^)(DFActionID actionID))success
               failure:(DFFailureBlock)failure;

- (void)addComment:(NSString *)comment
         toPhotoID:(DFPhotoIDType)photoID
     shareInstance:(DFShareInstanceIDType)shareInstance
           success:(void(^)(DFActionID actionID))success
           failure:(DFFailureBlock)failure;

- (void)deleteShareInstance:(DFShareInstanceIDType)shareInstanceID
                    success:(DFVoidBlock)success
                    failure:(DFFailureBlock)failure;

- (void)markPhotosAsNotOnSystem:(NSMutableArray *)photoIDs success:(DFSuccessBlock)success failure:(DFFailureBlock)failure;


/* Clears the data manager and makes way for creating a new one.
   Used when logging out of the app */
- (void)resetManager;

@end
