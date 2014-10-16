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

@interface DFPeanutFeedDataManager : NSObject

+ (DFPeanutFeedDataManager *)sharedManager;

- (void)refreshInboxFromServer:(void(^)(void))completion;
- (void)refreshPrivatePhotosFromServer:(void(^)(void))completion;

- (BOOL)hasData;

- (BOOL)isRefreshingInbox;

- (NSArray *)publicStrands;
- (NSArray *)privateStrands;
- (NSArray *)publicStrandsWithUser:(DFPeanutUserObject *)user;
- (NSArray *)privateStrandsWithUser:(DFPeanutUserObject *)user;
- (DFPeanutFeedObject *)strandPostsObjectWithId:(DFStrandIDType)strandPostsId;

/* returns a list of PeanutUsers */
- (NSArray *)friendsList;


- (void)acceptInvite:(DFPeanutFeedObject *)inviteFeedObject
         addPhotoIDs:(NSArray *)photoIDs
             success:(void(^)(void))success
             failure:(void(^)(NSError *error))failure;
@end
