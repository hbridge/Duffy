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

+ (DFPushNotificationsManager *)sharedManager
{
  static DFPushNotificationsManager *defaultManager = nil;
  if (!defaultManager) defaultManager = [[super allocWithZone:nil] init];
  return defaultManager;
}

+ (id)allocWithZone:(struct _NSZone *)zone
{
  return [self sharedManager];
}

- (void)promptForPushNotifsIfNecessary
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    DFPermissionStateType notifsState = [DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications];
    if (!notifsState || [notifsState isEqual:DFPermissionStateNotRequested]) {
      dispatch_async(dispatch_get_main_queue(), ^{
        DDLogInfo(@"%@ prompting for push notifs.", self.class);
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Receive Notifications"
                                  message:@"Would you like to get notifications when friends send you photos?"
                                  delegate:self
                                  cancelButtonTitle:@"Not Now"
                                  otherButtonTitles:@"Yes", nil];
        alertView.delegate = self;
        [alertView show];
        
      });
    }
  });
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex == 0) {
    DDLogInfo(@"%@ user said Not Now to push prompt.", self.class);
    [DFDefaultsStore setState:DFPermissionStatePreRequestedNotNow forPermission:DFPermissionRemoteNotifications];
  } else {
    DDLogInfo(@"%@ user said Yes to push prompt.", self.class);
    [DFDefaultsStore setState:DFPermissionStatePreRequestedYes forPermission:DFPermissionRemoteNotifications];
    [self.class requestPushNotifsPermission];
  }
}

+ (void)requestPushNotifsPermission
{
  DDLogInfo(@"%@ requesting push notifications.", self);
  if ([[UIApplication sharedApplication]
       respondsToSelector:@selector(registerUserNotificationSettings:)]) {
    // iOS 8
    DDLogInfo(@"%@ iOS8+ detected, calling registerUserNotificationSettings", self.class);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings
                                            settingsForTypes:UIUserNotificationTypeAlert
                                            | UIUserNotificationTypeBadge
                                            | UIUserNotificationTypeSound
                                            categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
  } else {
    DDLogInfo(@"%@ iOS7- detected, calling registerRemoteNotificationTypes", self.class);
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
     (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
  }
}

+ (void)refreshPushToken
{
  if ([[UIApplication sharedApplication]
       respondsToSelector:@selector(currentUserNotificationSettings)]) {
    // iOS 8
    UIUserNotificationSettings *settings = [[UIApplication sharedApplication]
                                            currentUserNotificationSettings];
    [DFDefaultsStore setLastUserNotificationType:settings.types];
  } else {
    [DFDefaultsStore setLastNotificationType:[[UIApplication sharedApplication] enabledRemoteNotificationTypes]];
  }
  
  if ([[DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications] isEqual:DFPermissionStateGranted]
      || [[DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications] isEqual:DFPermissionStatePreRequestedYes]) {
    [self requestPushNotifsPermission];
  }
}

// in iOS7, this is the callback we get after registerRemoteNotificationTypes
// in iOS8, we first get, registerUserNotificationSettings, then must call registerForRemoteNotifications
// THEN we get this callback
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

// in iOS8, this is the callback we get after registerUserNotificationSettings
+ (void)registerUserNotificationSettings:(UIUserNotificationSettings *)settings
{
  if (settings.types != UIUserNotificationTypeNone) {
    DDLogInfo(@"%@ userNotificationSettings not none, register for remote notifs", self.class);
    [DFDefaultsStore setLastUserNotificationType:settings.types];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
  } else {
    DDLogInfo(@"%@ userNotificationSettings are NONE not requesting remote notif", self.class);
    [DFDefaultsStore setState:DFPermissionStateDenied forPermission:DFPermissionRemoteNotifications];
    [DFDefaultsStore setLastUserNotificationType:settings.types];
  }
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
