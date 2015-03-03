//
//  DFPeanutAction.h
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"
#import "DFUser.h"
#import "DFPhoto.h"
#import "DFPeanutUserObject.h"
#import <EKObjectMapping.h>
#import <EKMappingProtocol.h>
/*
{
 "id": 324,
 "action_type": 0, // Favorite
        "photo": 295249,
 "user": 290,
 "time_stamp": 125235235235,
 "user_display_name": "Dan"
}
{
 "id": 325,
 "action_type": 4, // Comment
 "photo": 295249,
 "user": 290,
 "text": "Comment here...",
 "time_stamp": 125235235235,
 "user_display_name": "Dan"
}
 */

typedef UInt64 DFActionID;

@interface DFPeanutAction : NSObject <DFPeanutObject, EKMappingProtocol>

@property (nonatomic, retain) NSNumber *id;
@property (nonatomic) DFPeanutActionType action_type;
@property (nonatomic) DFUserIDType user;
@property (nonatomic, retain) NSNumber *photo;
@property (nonatomic, retain) NSNumber *share_instance;
@property (nonatomic, retain) NSNumber *strand;
@property (nonatomic, retain) NSNumber *target_user;
@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) NSDate *time_stamp;

+ (NSArray *)simpleAttributeKeys;
+ (EKObjectMapping *)objectMapping;

/* 
 Tests to see if the action is of a type recognized by the client
 Used to help ensure forwards-compatibility with feed data
 */
- (BOOL)isSupportedAction;

@end
