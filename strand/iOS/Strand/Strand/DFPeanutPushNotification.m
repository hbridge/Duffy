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

- (DFPhotoIDType)photoID
{
  return [(NSNumber *)self.userInfo[@"pid"] longLongValue];
}

- (DFScreenType)screenToShow
{
  if (self.userInfo[@"view"]) {
    return [(NSNumber *)self.userInfo[@"view"] intValue];
  }
  
  switch (self.type) {
    case DFPushNotifUnknown:
      return DFScreenCamera;
    case DFPushNotifNewPhotos:
      return DFScreenGallery;
    case DFPushNotifJoinable:
      return DFScreenCamera;
    case DFPushNotifFavorited:
      return DFScreenGallery;
    case DFPushNotifFirestarter:
      return DFScreenCamera;
    default:
      return DFScreenCamera;
  }
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


@end
