//
//  DFPushNotificationsManager.m
//  Strand
//
//  Created by Henry Bridge on 8/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAnalytics.h"
#import "DFBackgroundLocationManager.h"
#import "DFCreateStrandFlowViewController.h"
#import "DFDefaultsStore.h"
#import "DFPeanutFeedDataManager.h"
#import "DFPeanutPushNotification.h"
#import "DFPeanutPushTokenAdapter.h"
#import "DFPushNotificationsManager.h"
#import "DFToastNotificationManager.h"
#import "DFCardsPageViewController.h"
#import "DFPhotoDetailViewController.h"
#import "SVProgressHUD.h"
#import "DFDismissableModalViewController.h"

static BOOL ShowInAppNotifications = NO;

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
                                  message:@"Would you like to get notifications when friends send you photos or comment on your photos?"
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
  BOOL notifsEnabled = NO;
  if ([[UIApplication sharedApplication]
       respondsToSelector:@selector(currentUserNotificationSettings)]) {
    // iOS 8
    UIUserNotificationSettings *settings = [[UIApplication sharedApplication]
                                            currentUserNotificationSettings];
    [DFDefaultsStore setLastUserNotificationType:settings.types];
    if (settings.types != UIUserNotificationTypeNone) notifsEnabled = YES;
  } else {
    // iOS 7
    UIRemoteNotificationType notifTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    [DFDefaultsStore setLastNotificationType:notifTypes];
    if (notifTypes != UIRemoteNotificationTypeNone) notifsEnabled = YES;
  }
  
  DFPermissionStateType pushPermState = [DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications];
  if (notifsEnabled
      && !([pushPermState isEqual:DFPermissionStateGranted]
           || [pushPermState isEqual:DFPermissionStateUnavailable])) {
        DDLogWarn(@"%@ remoteNotifsEnabled but pushPermState:%@.  Changing pushPermState to %@",
                  self.class, pushPermState, DFPermissionStateGranted);
        pushPermState = DFPermissionStateGranted;
        [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionRemoteNotifications];
      }
  DDLogInfo(@"%@ refreshPushToken permissionState: %@", self, pushPermState);
  if ([pushPermState isEqual:DFPermissionStateGranted]
      || [pushPermState isEqual:DFPermissionStatePreRequestedYes]) {
    [self requestPushNotifsPermission];
  }
}

- (BOOL)pushNotificationsEnabled
{
  if ([[UIApplication sharedApplication]
       respondsToSelector:@selector(currentUserNotificationSettings)]) {
    // iOS 8
    UIUserNotificationSettings *settings = [[UIApplication sharedApplication]
                                            currentUserNotificationSettings];
    return settings.types != UIUserNotificationTypeNone;
  } else {
    return [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != UIRemoteNotificationTypeNone;
  }
  
  return NO;
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
  if (error.code == 3010) { // simulator
    [DFDefaultsStore setState:DFPermissionStateUnavailable
                forPermission:DFPermissionRemoteNotifications];
  } else if (error.code == 3000){ // app not provisioned
    if ([[DFUser currentUser] isUserDeveloper])
      [UIAlertView showSimpleAlertWithTitle:@"Push Failure"
                              formatMessage:@"Registration failed. Bad provisionining profile."];
  } else {
    [DFDefaultsStore setState:DFPermissionStateDenied
                forPermission:DFPermissionRemoteNotifications];
  }
  
}


#pragma mark - Handle incoming notification

- (void)handleNotificationForApp:(UIApplication *)application
                        userInfo:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  DFPeanutPushNotification *pushNotif = [[DFPeanutPushNotification alloc] initWithUserInfo:userInfo];
  if ([application applicationState] == UIApplicationStateBackground){
    if (pushNotif.contentAvailable && pushNotif.isUpdateLocationRequest)
    {
      [[DFBackgroundLocationManager sharedManager]
       backgroundUpdateWithCompletionHandler:completionHandler];
    }
  } else if ([application applicationState] == UIApplicationStateInactive) {
    if (pushNotif.type == NOTIFICATIONS_INVITED_TO_STRAND
        || pushNotif.type == NOTIFICATIONS_ACCEPTED_INVITE
        || pushNotif.type == NOTIFICATIONS_RETRO_FIRESTARTER
        || pushNotif.type == NOTIFICATIONS_PHOTO_FAVORITED_ID
        || pushNotif.type == NOTIFICATIONS_PHOTO_COMMENT
        || pushNotif.type == NOTIFICATIONS_NEW_PHOTO_ID)
    {
      DFNoticationOpenedHandler handler = [self openedHandlerForNotification:pushNotif];
      handler(pushNotif);
    }
  } else if ([application applicationState] == UIApplicationStateActive) {
    if ([pushNotif.message isNotEmpty] && ShowInAppNotifications) {
      [[DFToastNotificationManager sharedInstance]
       showNotificationForPush:pushNotif
       handler:[self openedHandlerForNotification:pushNotif]];
    }
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
     object:self];
  }
  
  if (completionHandler) completionHandler(UIBackgroundFetchResultNewData);
}

- (DFNoticationOpenedHandler)openedHandlerForNotification:(DFPeanutPushNotification *)pushNotif
{
  DFNoticationOpenedHandler handler = ^(DFPeanutPushNotification *openedNotif) {
    if (pushNotif.type == NOTIFICATIONS_NEW_PHOTO_ID ||
        pushNotif.type == NOTIFICATIONS_PHOTO_COMMENT ||
        pushNotif.type == NOTIFICATIONS_PHOTO_FAVORITED_ID) {
      
      DFShareInstanceIDType shareID = openedNotif.shareInstanceID.longLongValue;
      DFPhotoIDType photoID = openedNotif.id.longLongValue;
      
      DFPeanutFeedObject *photoObject = [[DFPeanutFeedDataManager sharedManager] photoWithID:photoID shareInstance:shareID];
      if (!photoObject) {
        [SVProgressHUD show];
        [[DFPeanutFeedDataManager sharedManager] refreshFeedFromServer:DFInboxFeed completion:^() {
          DFPeanutFeedObject *photoObject = [[DFPeanutFeedDataManager sharedManager]
                                             photoWithID:photoID
                                             shareInstance:shareID];
          if (photoObject) {
            [self openPhotoObject:photoObject];
            [SVProgressHUD dismiss];
          } else {
            [SVProgressHUD showErrorWithStatus:@"Failed"];
          }
        }];
      } else {
        [self openPhotoObject:photoObject];
      }
      
      [DFAnalytics logNotificationOpenedWithType:pushNotif.type];
    } else if (pushNotif.type == NOTIFICATIONS_RETRO_FIRESTARTER) {
      // This is very similar code to above, if we change this, might want to pull together
      NSArray *suggestedStrands = [[DFPeanutFeedDataManager sharedManager] suggestedStrands];
      DFPeanutFeedObject *foundObject;
      for (DFPeanutFeedObject *object in suggestedStrands) {
        if (object.id == openedNotif.id.longLongValue) {
          foundObject = object;
          break;
        }
      }
      
      if (!foundObject) {
        // if we don't find an object in the feed, we have to fake it so that when the feed
        // data manager gets the actual object, we sub in the correct data
        foundObject = [[DFPeanutFeedObject alloc] init];
        foundObject.id = openedNotif.id.longLongValue;
        foundObject.type = DFFeedObjectSwapSuggestion;
      }
      UIViewController *rootController = [[[[UIApplication sharedApplication] delegate] window]
                                          rootViewController];
      
      [DFCreateStrandFlowViewController presentFeedObject:foundObject modallyInViewController:rootController];
      [DFAnalytics logNotificationOpenedWithType:pushNotif.type];
    }
    
  };
  return handler;
}

- (void)openPhotoObject:(DFPeanutFeedObject *)photoObject
{
  UIViewController *vc =  [[DFPhotoDetailViewController alloc]
           initWithPhotoObject:photoObject];
      
  UIViewController *keyViewController = [[[[UIApplication sharedApplication] delegate] window]
                                         rootViewController];
  if (keyViewController.presentedViewController){
    [keyViewController dismissViewControllerAnimated:YES completion:^{
      [DFDismissableModalViewController presentWithRootController:vc
                                                         inParent:keyViewController];
    }];
  } else {
    [DFDismissableModalViewController presentWithRootController:vc
                                                       inParent:keyViewController];
  }
}


@end
