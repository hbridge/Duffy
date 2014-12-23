//
//  DFPeanutUserObject.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"
#import "DFUser.h"

@class CLLocation;

@interface DFPeanutUserObject : NSObject <DFPeanutObject>

@property (nonatomic) DFUserIDType id;
@property (nonatomic, retain) NSString *display_name;
@property (nonatomic, retain) NSString *phone_number;
@property (nonatomic, retain) NSString *phone_id;
@property (nonatomic, retain) NSString *auth_token;
@property (nonatomic, retain) NSString *device_token;
@property (nonatomic, retain) NSString *last_location_point;
@property (nonatomic, retain) NSNumber *last_location_accuracy;
@property (nonatomic, retain) NSDate *last_photo_timestamp;
@property (nonatomic, retain) NSDate *last_photo_update_timestamp;
@property (nonatomic, retain) NSDate *first_run_sync_timestamp;
@property (nonatomic, retain) NSNumber *first_run_sync_count;
@property (nonatomic, retain) NSNumber *invites_remaining;
@property (nonatomic, retain) NSNumber *invites_sent;
@property (nonatomic, retain) NSNumber *shared_strand;
@property (nonatomic, retain) NSNumber *has_sms_authed;
@property (nonatomic, retain) NSDate *added;
@property (nonatomic, retain) NSNumber *invited;

- (NSDictionary *)requestParameters;
- (void)setLocation:(CLLocation *)location;
- (NSString *)fullName;
- (NSString *)firstName;
- (UIImage *)thumbnail;
- (UIImage *)roundedThumbnailOfPointSize:(CGSize)size;

+ (DFPeanutUserObject *)TeamSwapUser;

@end
