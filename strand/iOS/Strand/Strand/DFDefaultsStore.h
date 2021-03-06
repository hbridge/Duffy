//
//  DFDefaultsStore.h
//  Strand
//
//  Created by Henry Bridge on 7/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFTypedefs.h"

@interface DFDefaultsStore : NSObject

//ios 7 notifs
+ (void)setLastNotificationType:(UIRemoteNotificationType)type;
+ (NSNumber *)lastNotificationType;

//ios 8 notifs
+ (void)setLastUserNotificationType:(UIUserNotificationType)type;
+ (NSNumber *)lastUserNotificationType;

+ (void)setState:(DFPermissionStateType)state forPermission:(DFPermissionType)permission;
+ (DFPermissionStateType)stateForPermission:(DFPermissionType)permission;

// whether setup steps have been passed
typedef NSString *const DFSetupStepType;
extern DFSetupStepType DFSetupStepAskToAutoSaveToCameraRoll;
extern DFSetupStepType DFSetupStepSendCameraRoll;
extern DFSetupStepType DFSetupStepSuggestionsNux;
+ (void)setSetupStepPassed:(DFSetupStepType)step Passed:(BOOL)passed;
+ (BOOL)isSetupStepPassed:(DFSetupStepType)step;

+ (void)setSetupStartedWithBuildNumber:(NSNumber *)buildNumber;
+ (void)setSetupCompletedForBuildNumber:(NSNumber *)buildNumber;
+ (void)setSetupCompletedStep:(NSNumber *)step;
+ (NSNumber *)setupIncompleteBuildNum;
+ (NSNumber *)setupCompletedBuildNum;
+ (NSNumber *)setupCompletedStepIndex;

// whether actions have happened
typedef NSString *const DFUserActionType;
extern DFUserActionType DFUserActionSendSuggestion;
extern DFUserActionType DFUserActionTakePhoto;
extern DFUserActionType DFUserActionTakeExternalPhoto;
extern DFUserActionType DFUserActionSyncContacts;
extern DFUserActionType DFUserActionSyncManualContacts;
extern DFUserActionType DFUserActionViewNotifications;
extern DFUserActionType DFUserActionLocationUpsellProcessed;
extern DFUserActionType DFUserActionLastBackgroundReferesh;

+ (void)incrementCountForAction:(DFUserActionType)action;
+ (unsigned int)actionCountForAction:(DFUserActionType)action;

// Flash
+ (void)setFlashMode:(UIImagePickerControllerCameraFlashMode)flashMode;
+ (UIImagePickerControllerCameraFlashMode)flashMode;

// Last date for action

+ (void)setLastDate:(NSDate *)date forAction:(DFUserActionType)action;
+ (NSDate *)lastDateForAction:(DFUserActionType)action;

@end
