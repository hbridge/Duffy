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
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIAlertView+DFHelpers.h"

NSString *const AutosaveToCameraRollDefaultsKey = @"DFSettingsAutosaveToCameraRoll";

@implementation DFSettings

static DFSettings *defaultSettings;
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

- (void)setDisplayName:(NSString *)displayName
{
  DFUser *currentUser = [DFUser currentUser];
  currentUser.displayName = displayName;
  [DFUser setCurrentUser:currentUser];
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

@end
