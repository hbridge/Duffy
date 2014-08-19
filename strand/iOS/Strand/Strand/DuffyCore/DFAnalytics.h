//
//  DFAnalytics.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MessageUI/MFMessageComposeViewController.h>
#import "DFTypedefs.h"

@interface DFAnalytics : NSObject

extern NSString * const DFAnalyticsActionTypeSwipe;
extern NSString* const DFAnalyticsValueResultSuccess;
extern NSString* const DFAnalyticsValueResultFailure;
extern NSString* const DFAnalyticsValueResultAborted;
extern NSString* const DFAnalyticsValueResultInvalidInput;

/* Stop and Start Session Helpers */
+ (void)StartAnalyticsSession;
+ (void)ResumeAnalyticsSession;
+ (void)CloseAnalyticsSession;

/* App Setup and Permissions */

+ (void)logSetupPhoneNumberEnteredWithResult:(NSString *)result;
+ (void)logSetupSMSCodeEnteredWithResult:(NSString *)result;
+ (void)logSetupLocationCompletedWithResult:(NSString *)result
                        userTappedLearnMore:(BOOL)didTapLearnMore;
+ (void)logSetupContactsCompletedWithABPermission:(int)status
                                 numAddedManually:(NSUInteger)numAddedManually;

+ (void)logRemoteNotifsChangedFromOldNotificationType:(UIRemoteNotificationType)oldType
                                              newType:(UIRemoteNotificationType)newType;
+ (void)logPermissionsChanges;
+ (void)logPermission:(DFPermissionType)permission
  changedWithOldState:(DFPermissionStateType)oldState
             newState:(DFPermissionStateType)newState;

/* Generic logging for view controllers */
+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params;
+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params;

/* Uploads */
+ (void)logUploadEndedWithResult:(NSString *)resultValue;
+ (void)logUploadEndedWithResult:(NSString *)resultValue numPhotos:(unsigned long)numPhotos sessionAvgThroughputKBPS:(double)KBPS;
+ (void)logUploadEndedWithResult:(NSString *)resultValue debug:(NSString *)debug;
+ (void)logUploadCancelledWithIsError:(BOOL)isError;
+ (void)logUploadRetryCountExceededWithCount:(unsigned int)count;

/* Log camera and photo actions */
+ (void)logPhotoTakenWithCamera:(UIImagePickerControllerCameraDevice)camera
                      flashMode:(UIImagePickerControllerCameraFlashMode)flashMode;
+ (void)logPhotoSavedWithResult:(NSString *)result;
+ (void)logSwitchBetweenPhotos:(NSString *)actionType;
+ (void)logPhotoLoadWithResult:(NSString *)result;
+ (void)logPhotoDeletedWithResult:(NSString *)result
           timeIntervalSinceTaken:(NSTimeInterval)timeInterval;
+ (void)logPhotoLikePressedWithNewValue:(BOOL)isOn
                                 result:(NSString *)result
                             actionType:(DFActionType)actionType
                 timeIntervalSinceTaken:(NSTimeInterval)timeInterval;

/* Notification response */
+ (void)logNotificationOpenedWithType:(DFPushNotifType)type;
+ (void)logNotificationViewItemOpened:(NSString *)type notifDate:(NSDate *)notifDate;

/* Inviting */

+ (void)logInviteComposeFinishedWithResult:(MessageComposeResult)result
                  presentingViewController:(UIViewController *)presentingViewController;


/* Contacts */
+ (void)logAddContactCompletedWithResult:(NSString *)result;


@end
