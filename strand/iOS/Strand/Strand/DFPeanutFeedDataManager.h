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

+ (DFPeanutFeedDataManager *)sharedManager;

- (void)refreshInboxFromServer:(void(^)(void))completion;
- (void)refreshPrivatePhotosFromServer:(void(^)(void))completion;
- (void)refreshSwapsFromServer:(void(^)(void))completion;

- (BOOL)hasInboxData;
- (BOOL)hasPrivateStrandData;

- (BOOL)isRefreshingInbox;

- (NSArray *)publicStrands;
- (NSArray *)inviteStrands;
- (NSArray *)acceptedStrands;
- (NSArray *)privateStrands;
- (NSArray *)privateStrandsByDateAscending:(BOOL)ascending;
- (NSArray *)remotePhotos;
- (NSArray *)suggestedStrands;
- (NSArray *)publicStrandsWithUser:(DFPeanutUserObject *)user;
- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user;

- (DFPeanutFeedObject *)strandPostsObjectWithId:(DFStrandIDType)strandPostsId;
- (DFPeanutFeedObject *)inviteObjectWithId:(DFInviteIDType)inviteId;
- (DFPeanutFeedObject *)photoWithId:(DFPhotoIDType)photoID;


/* returns a list of PeanutUsers */
- (NSArray *)friendsList;


- (void)acceptInvite:(DFPeanutFeedObject *)inviteFeedObject
         addPhotoIDs:(NSArray *)photoIDs
             success:(void(^)(void))success
             failure:(void(^)(NSError *error))failure;
- (void)markSuggestion:(DFPeanutFeedObject *)suggestedSection visible:(BOOL)visible;


- (void)createNewStrandWithPhotos:(NSArray *)feedPhotoObjects
           createdFromSuggestions:(NSArray *)suggestedSections
           selectedPeanutContacts:(NSArray *)selectedPeanutContacts
                          success:(void(^)(DFPeanutStrand *resultStrand))success
                          failure:(DFFailureBlock)failure;

@end
