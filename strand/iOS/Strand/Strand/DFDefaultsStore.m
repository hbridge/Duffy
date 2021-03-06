//
//  DFDefaultsStore.m
//  Strand
//
//  Created by Henry Bridge on 7/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDefaultsStore.h"
#import "DFAnalytics.h"

@implementation DFDefaultsStore

NSString *const DFDefaultsNotifsTypeKey = @"DFStrandLastNotifTypes";
NSString *const DFDefaultsUserNotifsTypeKey = @"DFStrandLastUserNotifTypes";

+ (void)setLastNotificationType:(UIRemoteNotificationType)type
{
  NSNumber *lastNotifType = [DFDefaultsStore lastNotificationType];
  if (![lastNotifType isEqual:@(type)]) {
    [DFAnalytics logRemoteNotifsChangedFromOldNotificationType:lastNotifType.intValue newType:type];
    [[NSUserDefaults standardUserDefaults] setObject:@(type) forKey:DFDefaultsNotifsTypeKey];
  }
}

+ (void)setLastUserNotificationType:(UIUserNotificationType)type
{
  NSNumber *lastUserNotifType = [DFDefaultsStore lastUserNotificationType];
  if (![lastUserNotifType isEqual:@(type)]) {
    
    [[NSUserDefaults standardUserDefaults] setObject:@(type) forKey:DFDefaultsUserNotifsTypeKey];
  }
}

+ (NSNumber *)lastNotificationType
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:DFDefaultsNotifsTypeKey];
}

+ (NSNumber *)lastUserNotificationType
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:DFDefaultsUserNotifsTypeKey];
}


// Permissions
+ (NSString *)keyForPermission:(DFPermissionType)permission
{
  return [NSString stringWithFormat:@"DFPermission%@", permission];
}

+ (void)setState:(DFPermissionStateType)state forPermission:(DFPermissionType)permission
{
  DFPermissionStateType oldState = [self stateForPermission:permission];
  if (!state) state = DFPermissionStateNotRequested;
  if (!oldState) oldState = DFPermissionStateNotRequested;
  if (![state isEqual:oldState] && state != oldState) {
    [DFAnalytics logPermission:permission
           changedWithOldState:oldState newState:state];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFPermissionStateChangedNotificationName
       object:nil
       userInfo:@{DFPermissionTypeKey : permission,
                  DFPermissionOldStateKey: oldState,
                  DFPermissionNewStateKey: state}];
    });
    [[NSUserDefaults standardUserDefaults] setObject:state forKey:[self keyForPermission:permission]];
  }
}

+ (DFPermissionStateType)stateForPermission:(DFPermissionType)permission
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:[self keyForPermission:permission]];
}

// Actions

NSString *const UserActionCountPrefix = @"DFUserActionCount";
NSString *const UserActionDatePrefix = @"DFLastUserActionDate";

DFUserActionType DFUserActionTakePhoto = @"TakePhoto";
DFUserActionType DFUserActionSendSuggestion = @"SendSuggestion";
DFUserActionType DFUserActionTakeExternalPhoto = @"TakeExternalPhoto";
DFUserActionType DFUserActionSyncContacts = @"SyncContacts";
DFUserActionType DFUserActionSyncManualContacts = @"SyncManualContacts";
DFUserActionType DFUserActionViewNotifications = @"ViewNotifications";
DFUserActionType DFUserActionLocationUpsellProcessed = @"DFUserActionLocationUpsellNotNowed";
DFUserActionType DFUserActionLastBackgroundReferesh = @"DFUserActionLastBackgroundReferesh";


+ (void)incrementCountForAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionCountPrefix, action];
  NSNumber *count = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  unsigned int newCount = [count unsignedIntValue] + 1;
  [[NSUserDefaults standardUserDefaults] setObject:@(newCount) forKey:key];
}

+ (unsigned int)actionCountForAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionCountPrefix, action];
  NSNumber *count = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  return [count unsignedIntValue];
}

+ (void)setLastDate:(NSDate *)date forAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionDatePrefix, action];
  [[NSUserDefaults standardUserDefaults] setObject:date forKey:key];
}

+ (NSDate *)lastDateForAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionDatePrefix, action];
  return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

// whether setup steps have been passed
DFSetupStepType DFSetupStepAskToAutoSaveToCameraRoll = @"DFSetupStepAskToAutoSaveToCameraRoll";
DFSetupStepType DFSetupStepSuggestionsNux = @"DFSetupStepSuggestionNux";
DFSetupStepType DFSetupStepSendCameraRoll = @"DFSetupStepSendCameraRoll";

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


+ (void)setSetupStartedWithBuildNumber:(NSNumber *)buildNumber
{
  [[NSUserDefaults standardUserDefaults] setObject:buildNumber forKey:@"SetupStartedBuildNumber"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setSetupCompletedForBuildNumber:(NSNumber *)buildNumber
{
  [[NSUserDefaults standardUserDefaults] setObject:buildNumber forKey:@"SetupCompletedBuildNumber"];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SetupStartedBuildNumber"];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SetupCompletedStepNum"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setSetupCompletedStep:(NSNumber *)step
{
  [[NSUserDefaults standardUserDefaults] setObject:step forKey:@"SetupCompletedStepNum"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSNumber *)setupIncompleteBuildNum
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:@"SetupStartedBuildNumber"];
}

+ (NSNumber *)setupCompletedBuildNum;
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:@"SetupCompletedBuildNumber"];
}

+ (NSNumber *)setupCompletedStepIndex
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:@"SetupCompletedStepNum"];
}




@end
