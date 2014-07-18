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

- (void)setContentAvailableFromUserInfo:(NSDictionary *)userInfo
{
  NSDictionary *apsDict = userInfo[@"aps"];
  NSNumber *contentAvailable = apsDict[@"content-available"];
  _contentAvailable = [contentAvailable boolValue];
}

- (DFScreenType)screenToShow
{
  if (!self.userInfo[@"view"]) return DFScreenNone;
  
  int viewNumber = [(NSNumber *)self.userInfo[@"view"] intValue];
  return (DFScreenType)(viewNumber);
}

- (BOOL)isUpdateLocationRequest
{
  if (!self.userInfo[@"fgps"]) return NO;
  return [(NSNumber *)self.userInfo[@"fgps"] boolValue];
}


@end
