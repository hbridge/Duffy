//
//  DFInboxDataManager.h
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutUserObject.h"

@interface DFPeanutFeedDataManager : NSObject

@property (nonatomic, retain) NSArray *inboxFeedObjects;

+ (DFPeanutFeedDataManager *)sharedManager;

- (void)refreshFromServer:(void(^)(void))completion;
- (BOOL)hasData;
- (NSArray *)strandsWithUser:(DFPeanutUserObject *)user;
- (NSArray *)friendsList;
@end
