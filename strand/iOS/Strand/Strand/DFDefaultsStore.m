//
//  DFDefaultsStore.m
//  Strand
//
//  Created by Henry Bridge on 7/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDefaultsStore.h"

@implementation DFDefaultsStore

NSString *const DFDefaultsNotifsTypeKey = @"DFStrandLastNotifTypes";

+ (void)setLastNotificationType:(UIRemoteNotificationType)type
{
  [[NSUserDefaults standardUserDefaults] setObject:@(type) forKey:DFDefaultsNotifsTypeKey];
}

+ (NSNumber *)lastNotificationType
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:DFDefaultsNotifsTypeKey];
}

// Permissions
+ (NSString *)keyForPermission:(DFPermissionType)permission
{
  return [NSString stringWithFormat:@"DFPermission%@", permission];
}

+ (void)setState:(DFPermissionStateType)state forPermission:(DFPermissionType)permission
{
  [[NSUserDefaults standardUserDefaults] setObject:state forKey:[self keyForPermission:permission]];
}

+ (DFPermissionStateType)stateForPermission:(DFPermissionType)permission
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:[self keyForPermission:permission]];
}

// Actions

NSString *const UserActionPrefix = @"DFUserActionCount";
DFUserActionType UserActionTakePhoto = @"TakePhoto";

+ (void)incrementCountForAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionPrefix, action];
  NSNumber *count = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  unsigned int newCount = [count unsignedIntValue] + 1;
  [[NSUserDefaults standardUserDefaults] setObject:@(newCount) forKey:key];
}


+ (unsigned int)actionCountForAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionPrefix, action];
  NSNumber *count = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  return [count unsignedIntValue];
}


// whether setup steps have been passed
DFSetupStepType DFSetupStepAskToAutoSaveToCameraRoll = @"DFSetupStepAskToAutoSaveToCameraRoll";

+ (void)setSetupStepPassed:(DFSetupStepType)step Passed:(BOOL)passed
{
  [[NSUserDefaults standardUserDefaults] setBool:passed forKey:step];
}

+ (BOOL)isSetupStepPassed:(DFSetupStepType)step;
{
  return [[NSUserDefaults standardUserDefaults] boolForKey:step];
}

// Flash
+ (void)setFlashMode:(UIImagePickerControllerCameraFlashMode)flashMode
{
  [[NSUserDefaults standardUserDefaults] setObject:@(flashMode) forKey:@"FlashMode"];
}

+ (UIImagePickerControllerCameraFlashMode)flashMode
{
  NSNumber *flashMode = [[NSUserDefaults standardUserDefaults] objectForKey:@"FlashMode"];
  return [flashMode intValue];
}


@end
