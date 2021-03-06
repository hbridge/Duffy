//
//  DFPeanutNotification.h
//  Strand
//
//  Created by Derek Parham on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutObject.h"

/*
 {
 "photo_id": 295922,
 "action_text": "Derek liked your photo",
 "actor_user": 337,
 "time": 1405449026
 },
 */

@interface DFPeanutNotification : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSNumber *photo_id;
@property (nonatomic, retain) NSString *action_text;
@property (nonatomic, retain) NSString *photo_thumb_path;
@property (nonatomic, retain) NSNumber *actor_user;
@property (nonatomic, retain) NSString *actor_display_name;
@property (nonatomic, retain) NSDate *time;

@end
