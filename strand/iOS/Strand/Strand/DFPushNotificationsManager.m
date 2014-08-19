//
//  DFPushNotificationsManager.m
//  Strand
//
//  Created by Henry Bridge on 8/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPushNotificationsManager.h"
#import "DFDefaultsStore.h"
#import "DFAnalytics.h"
#import "DFPeanutPushTokenAdapter.h"

@implementation DFPushNotificationsManager


+ (void)requestPushNotifs
{
  DDLogInfo(@"%@ requesting push notifications.", self);
  [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
   (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
}

+ (void)refreshPushToken
{
  [DFDefaultsStore setLastNotificationType:[[UIApplication sharedApplication] enabledRemoteNotificationTypes]];
  if ([[DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications] isEqual:DFPermissionStateGranted]) {
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
     (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
  }
}

+ (void)registerDeviceToken:(NSData *)data
{
  DFPeanutPushTokenAdapter *pushTokenAdapter = [[DFPeanutPushTokenAdapter alloc] init];
  
  [pushTokenAdapter registerAPNSToken:data  completionBlock:^(BOOL success) {
    if (success) {
      DDLogInfo(@"%@ push token successfuly registered with server.", self);
    } else {
      DDLogInfo(@"%@ push token FAILED to register with server!", self);
    }
  }];
  
  [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionRemoteNotifications];
}

+ (void)registerFailedWithError:(NSError *)error
{
  DDLogWarn(@"%@ failed to get push token, error: %@", self, error);
  if (error.code == 3010) {
    [DFDefaultsStore setState:DFPermissionStateUnavailable
                forPermission:DFPermissionRemoteNotifications];
  } else {
    [DFDefaultsStore setState:DFPermissionStateDenied
                forPermission:DFPermissionRemoteNotifications];
  }
  
}


@end
