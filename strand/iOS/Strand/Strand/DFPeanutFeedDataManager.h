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

- (BOOL)hasInboxData;
- (BOOL)hasPrivateStrandData;
- (BOOL)hasSwapsData;

- (BOOL)isRefreshingInbox;

- (NSArray *)publicStrands;
- (NSArray *)inviteStrands;
- (NSArray *)acceptedStrands;
- (NSArray *)privateStrands;
- (NSArray *)privatePhotos;
- (NSArray *)privateStrandsByDateAscending:(BOOL)ascending;
- (NSArray *)remotePhotos;
- (NSArray *)suggestedStrands;
- (NSArray *)publicStrandsWithUser:(DFPeanutUserObject *)user includeInvites:(BOOL)includeInvites;
- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user;
- (NSArray *)actionsList;

- (DFPeanutFeedObject *)strandPostsObjectWithId:(DFStrandIDType)strandPostsId;
- (DFPeanutFeedObject *)inviteObjectWithId:(DFInviteIDType)inviteId;
- (DFPeanutFeedObject *)photoWithId:(DFPhotoIDType)photoID;


/* returns a list of PeanutUsers */
- (NSArray *)friendsList;


- (void)acceptInvite:(DFPeanutFeedObject *)inviteFeedObject
         addPhotoIDs:(NSArray *)photoIDs
             success:(void(^)(void))success
             failure:(void(^)(NSError *error))failure;

- (void)addFeedObjects:(NSArray *)photos
         toStrandPosts:(DFPeanutFeedObject *)strandPosts
               success:(DFSuccessBlock)success
               failure:(DFFailureBlock)failure;

- (void)markSuggestion:(DFPeanutFeedObject *)suggestedSection visible:(BOOL)visible;


- (void)createNewStrandWithFeedObjects:(NSArray *)feedObjects
           createdFromSuggestions:(NSArray *)suggestedSections
           selectedPeanutContacts:(NSArray *)selectedPeanutContacts
                          success:(void(^)(DFPeanutStrand *resultStrand))success
                          failure:(DFFailureBlock)failure;

- (void)removePhoto:(DFPeanutFeedObject *)photoObject
    fromStrandPosts:(DFPeanutFeedObject *)strandPosts
            success:(DFSuccessBlock)success
            failure:(DFFailureBlock)failure;

@end
