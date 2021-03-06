//
//  DFPeanutUserObject.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EKObjectMapping.h>
#import <EKMappingProtocol.h>
#import "DFPeanutObject.h"
#import "DFUser.h"

@class CLLocation;
@class DFPeanutContact;

@interface DFPeanutUserObject : NSObject <DFPeanutObject, EKMappingProtocol>

typedef NSString *const DFPeanutUserRelationshipType;
extern DFPeanutUserRelationshipType DFPeanutUserRelationshipFriend;
extern DFPeanutUserRelationshipType DFPeanutUserRelationshipForwardFriend;
extern DFPeanutUserRelationshipType DFPeanutUserRelationshipReverseFriend;
extern DFPeanutUserRelationshipType DFPeanutUserRelationshipConnection;

@property (nonatomic) DFUserIDType id;
@property (nonatomic, retain) NSString *display_name;
@property (nonatomic, retain) NSString *phone_number;
@property (nonatomic, retain) NSString *phone_id;
@property (nonatomic, retain) NSString *auth_token;
@property (nonatomic, retain) NSString *device_token;
@property (nonatomic, retain) NSString *last_location_point;
@property (nonatomic, retain) NSNumber *last_location_accuracy;
@property (nonatomic, retain) NSDate *last_checkin_timestamp;
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
@property (nonatomic, retain) NSNumber *friend_connection_id;

// Temporary field for backwards compatibility
@property (nonatomic, retain) NSNumber *forward_friend_only;
@property (nonatomic, retain) NSString *relationship;
@property (nonatomic, retain) NSDate *last_actions_list_request_timestamp;

- (NSDictionary *)requestParameters;
- (void)setLocation:(CLLocation *)location;
- (NSString *)fullName;
- (NSString *)firstName;
- (UIImage *)thumbnail;
- (UIImage *)roundedThumbnailOfPointSize:(CGSize)size;
- (BOOL)hasAuthedPhone;
- (instancetype)initWithPeanutContact:(DFPeanutContact *)peanutContact;
+ (NSArray *)peanutUsersFromPeanutContacts:(NSArray *)peanutContacts;

+ (DFPeanutUserObject *)TeamSwapUser;
+ (EKObjectMapping *)objectMapping;


@end
