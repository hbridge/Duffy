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

/*
{
 "id": 324,
 "action_type": "favorite",
        "photo": 295249,
 "user": 290,
 "user_display_name": "Dan"
}
 */

typedef UInt64 DFActionID;

@interface DFPeanutAction : NSObject <DFPeanutObject>

@property (nonatomic) DFActionID id;
@property (nonatomic, retain) DFPeanutActionType action_type;
@property (nonatomic) DFPhotoIDType photo;
@property (nonatomic) DFUserIDType user;
@property (nonatomic, retain) NSString *user_display_name;

+ (NSArray *)simpleAttributeKeys;

+ (NSArray *)arrayOfLikerNamesFromActions:(NSArray *)actionArray;

@end
