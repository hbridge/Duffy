//
//  DFSettings.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSettings.h"
#import "DFAppInfo.h"
#import "DFUser.h"
#import "DFUserPeanutAdapter.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIAlertView+DFHelpers.h"
#import "DFPushNotificationsManager.h"
#import "DFBackgroundLocationManager.h"
#import "DFDefaultsStore.h"
#import "DFAlertController.h"

NSString *const AutosaveToCameraRollDefaultsKey = @"DFSettingsAutosaveToCameraRoll";

@interface DFSettings ()

@property (readonly, nonatomic, retain) DFUserPeanutAdapter *userAdapter;

@end

@implementation DFSettings

static DFSettings *defaultSettings;

@synthesize userAdapter = _userAdapter;

+ (DFSettings *)sharedSettings
{
  if (!defaultSettings) {
    defaultSettings = [[super allocWithZone:nil] init];
  }
  return defaultSettings;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedSettings];
}

/*
  Called when the display name is changed, want to save new name locally and on server.
  */
- (void)setDisplayName:(NSString *)displayName
{
  DFUser *currentUser = [DFUser currentUser];
  // Save copy of string incase there's a failure
  NSString *oldDisplayName = currentUser.displayName;
  
  // This updates the local user data so the UI is correct
  currentUser.displayName = displayName;
  
  // Create a PeanutUser to use for sending to the server, set only the display name
  DFPeanutUserObject *peanutUser = [[DFPeanutUserObject alloc] init];
  peanutUser.id = currentUser.userID;
  peanutUser.display_name = displayName;
  
  // Do the HTTP PATCH to the server
  [self.userAdapter
   performRequest:RKRequestMethodPATCH
   withPeanutUser:peanutUser
   success:^(DFPeanutUserObject *user) {
     // This writes the settings to local disk since the server returned success
     [DFUser setCurrentUser:currentUser];
     DDLogInfo(@"Successfully updated user object on server after display name change");
   }
   failure:^(NSError *error) {
     // Revert local user copy back to old data
     currentUser.displayName = oldDisplayName;
     DDLogError(@"%@ put of user object %@ failed with error: %@",
                [self.class description],
                peanutUser,
                error.description);
     [UIAlertView showSimpleAlertWithTitle:@"Error"
                                   message:[NSString stringWithFormat:
                                            @"Could not update display name. %@",
                                            error.localizedDescription]];
   }];
}

- (NSString *)displayName
{
  return [[DFUser currentUser] displayName];
}

- (NSString *)version
{
  return [DFAppInfo appInfoString];
}

- (NSString *)phoneNumber
{
  return [[DFUser currentUser] phoneNumberString];
}

- (BOOL)autosaveToCameraRoll
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:AutosaveToCameraRollDefaultsKey];
}

- (void)setAutosaveToCameraRoll:(BOOL)autosaveToCameraRoll
{
  if (autosaveToCameraRoll) {
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (status == ALAuthorizationStatusAuthorized) {
      [[NSUserDefaults standardUserDefaults] setBool:autosaveToCameraRoll
                                              forKey:AutosaveToCameraRollDefaultsKey];
    } else if (status == ALAuthorizationStatusDenied) {
      [UIAlertView showSimpleAlertWithTitle:@"Enable Access"
                                    message:@"Please give this app permission to access your photo library in Settings."];
    } else if (status == ALAuthorizationStatusRestricted) {
      [UIAlertView showSimpleAlertWithTitle:@"Restricted"
                                    message:@"Cannot enable.  Access to the photo library is restricted on this phone."];
    } else if (status == ALAuthorizationStatusNotDetermined) {
      ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
      
      [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
      } failureBlock:^(NSError *error) {
        if (error) {
          [UIAlertView showSimpleAlertWithTitle:@"Error"
                                        message:[NSString stringWithFormat:@"Cannot enable: %@",
                                                 error.localizedDescription]];
          DDLogWarn(@"Couldn't access camera roll, code: %ld", (long)error.code);
        }else{
          [[NSUserDefaults standardUserDefaults] setBool:autosaveToCameraRoll
                                                  forKey:AutosaveToCameraRollDefaultsKey];
        }
      }];
    }
  } else {
    [[NSUserDefaults standardUserDefaults] setBool:autosaveToCameraRoll
                                          forKey:AutosaveToCameraRollDefaultsKey];
  }
}


- (NSString *)serverURL
{
  NSString *urlString = [[DFUser currentUser] userServerURLString];
  return urlString;
}

- (void)setServerURL:(NSString *)newURL
{
  [[DFUser currentUser] setUserServerURLString:newURL];
}

- (NSString *)serverPort
{
  return [[DFUser currentUser] userServerPortString];
}

- (void)setServerPort:(NSString *)serverPort
{
  [[DFUser currentUser] setUserServerPortString:serverPort];
}

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) _userAdapter = [[DFUserPeanutAdapter alloc] init];
  return _userAdapter;
}

- (NSString *)userID
{
  return [@([[DFUser currentUser] userID]) stringValue];
}


- (BOOL)pushNotificationsEnabled
{
  return [[DFPushNotificationsManager sharedManager] pushNotificationsEnabled];
}

- (void)setPushNotificationsEnabled:(BOOL)pushNotifications
{
  if (pushNotifications &&
      [[DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications] isEqual:DFPermissionStateDenied]) {
    [self.class showPermissionDeniedAlert];
  } else if (pushNotifications) {
    [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
  }
}

- (void)setLocationEnabled:(BOOL)locationEnabled
{
  if ([[DFDefaultsStore stateForPermission:DFPermissionLocation] isEqual:DFPermissionStateDenied]) {
    if (locationEnabled) {
      [self.class showPermissionDeniedAlert];
    }
  }
  else if (locationEnabled) {
    [[DFBackgroundLocationManager sharedManager] promptForAuthorization];
  }
}

- (BOOL)locationEnabled
{
  return [[DFBackgroundLocationManager sharedManager] isPermssionGranted];
}

+ (void)showPermissionDeniedAlert
{
  DFAlertController *alert = [DFAlertController
                              alertControllerWithTitle:@"Grant Permission"
                              message:@"You have previously denied access.  Please grant permission in Settings."
                              preferredStyle:DFAlertControllerStyleAlert];
  [alert addAction:[DFAlertAction actionWithTitle:@"Cancel" style:DFAlertActionStyleCancel handler:nil]];
  [alert addAction:[DFAlertAction
                    actionWithTitle:@"Settings"
                    style:DFAlertActionStyleDefault
                    handler:^(DFAlertAction *action) {
                      if (&UIApplicationOpenSettingsURLString != NULL) {
                        NSURL *appSettings = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                        [[UIApplication sharedApplication] openURL:appSettings];
    }
  }]];
  
  UIViewController *vc = [self topMostController];
  [alert showWithParentViewController:vc animated:YES completion:nil];
}

+ (UIViewController*) topMostController
{
  UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
  
  while (topController.presentedViewController) {
    topController = topController.presentedViewController;
  }
  
  return topController;
}


@end
