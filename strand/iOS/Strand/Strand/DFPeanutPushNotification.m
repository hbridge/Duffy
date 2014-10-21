//
//  DFPeanutPushNotification.m
//  Strand
//
//  Created by Henry Bridge on 7/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutPushNotification.h"


@interface DFPeanutPushNotification()

@property (nonatomic, retain) NSDictionary *userInfo;

@end

@implementation DFPeanutPushNotification

@synthesize message = _message;
@synthesize contentAvailable = _contentAvailable;


- (instancetype)initWithUserInfo:(NSDictionary *)userInfo
{
  self = [super init];
  if (self) {
    _userInfo = userInfo;
    [self setMessageFromUserInfo:userInfo];
    [self setTypeFromUserInfo:userInfo];
    [self setContentAvailableFromUserInfo:userInfo];
  }
  return self;
}

- (void)setMessageFromUserInfo:(NSDictionary *)userInfo
{
  NSDictionary *apsDict = userInfo[@"aps"];
  id alert = apsDict[@"alert"];
  if ([[alert class] isSubclassOfClass:[NSDictionary class]]) {
    NSDictionary *alertDict = (NSDictionary *)alert;
    _message = alertDict[@"body"];
  } else if ([[alert class] isSubclassOfClass:[NSString class]]) {
    _message = alert;
  } else {
    DDLogWarn(@"%@ trying to set message from notif of unknown format.  userInfo:%@",
              [self.class description], self.userInfo);
  }
}

- (void)setTypeFromUserInfo:(NSDictionary *)userInfo
{
  _type =  [(NSNumber *)self.userInfo[@"type"] intValue];
}

- (void)setContentAvailableFromUserInfo:(NSDictionary *)userInfo
{
  NSDictionary *apsDict = userInfo[@"aps"];
  NSNumber *contentAvailable = apsDict[@"content-available"];
  _contentAvailable = [contentAvailable boolValue];
}

- (NSNumber *)id
{
  return self.userInfo[@"id"];
}

- (BOOL)isUpdateLocationRequest
{
  if (!self.userInfo[@"fgps"]) return NO;
  return [(NSNumber *)self.userInfo[@"fgps"] boolValue];
}

- (BOOL)isUpdateFeedRequest
{
  if (!self.userInfo[@"ff"]) return NO;
  return [(NSNumber *)self.userInfo[@"ff"] boolValue];
}

- (NSString *)description{
  return self.userInfo.description;
}

- (NSString *)typeString
{
  return [self.class pushNotifTypeToString:self.type];
}

static NSArray *typeStrings = nil;
+ (NSString *)pushNotifTypeToString:(DFPushNotifType)type
{
  if (!typeStrings) {
    typeStrings = @[@"UNKNOWN",
                    @"NOTIFICATIONS_NEW_PHOTO_ID",
                    @"NOTIFICATIONS_JOIN_STRAND_ID",
                    @"NOTIFICATIONS_PHOTO_FAVORITED_ID",
                    @"NOTIFICATIONS_FETCH_GPS_ID",
                    @"NOTIFICATIONS_RAW_FIRESTARTER_ID",
                    @"NOTIFICATIONS_PHOTO_FIRESTARTER_ID",
                    @"NOTIFICATIONS_PHOTO_FIRESTARTER_ID",
                    @"NOTIFICATIONS_REFRESH_FEED",
                    @"NOTIFICATIONS_SOCKET_REFRESH_FEED",
                    @"NOTIFICATIONS_INVITED_TO_STRAND",
                    @"NOTIFICATIONS_ACCEPTED_INVITE",
                    ];
  }
  
  if ((int)type > typeStrings.count - 1) return @"UNKNOWN";
  return typeStrings[type];
}



@end
