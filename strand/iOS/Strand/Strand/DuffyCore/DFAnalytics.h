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

@class DFPeanutFeedObject;

@interface DFAnalytics : NSObject

extern NSString * const DFAnalyticsActionTypeTap;
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
+ (void)logSetupPhotosCompletedWithResult:(NSString *)result;

// ios 7 notifs
+ (void)logRemoteNotifsChangedFromOldNotificationType:(UIRemoteNotificationType)oldType
                                              newType:(UIRemoteNotificationType)newType;

//ios 8 notifs
+ (void)logUserNotifsChangedFromOldNotificationType:(UIUserNotificationType)oldType
                                            newType:(UIUserNotificationType)newType;
+ (void)logPermissionsChanges;
+ (void)logPermission:(DFPermissionType)permission
  changedWithOldState:(DFPermissionStateType)oldState
             newState:(DFPermissionStateType)newState;

/* Generic logging for view controllers */
+ (void)logViewController:(UIViewController *)viewController
   appearedWithParameters:(NSDictionary *)params;
+ (void)logViewController:(UIViewController *)viewController
disappearedWithParameters:(NSDictionary *)params;

/* Create strand */
+ (void)logCreateStrandFlowCompletedWithResult:(NSString *)result
                             numPhotosSelected:(NSUInteger)numPhotos
                             numPeopleSelected:(NSUInteger)numPeople
                                     extraInfo:(NSDictionary *)extraInfo;

/* Log camera and photo actions */
+ (void)logPhotoActionTaken:(DFPeanutActionType)action
         fromViewController:(UIViewController *)viewController
                     result:(NSString *)result
                photoObject:(DFPeanutFeedObject *)photo
                postsObject:(DFPeanutFeedObject *)postsObject;
+ (void)logPhotoSavedWithResult:(NSString *)result;
+ (void)logPhotoDeletedWithResult:(NSString *)result
           timeIntervalSinceTaken:(NSTimeInterval)timeInterval;
+ (void)logPhotoLikePressedWithNewValue:(BOOL)isOn
                                 result:(NSString *)result
                             actionType:(DFUIActionType)actionType
                 timeIntervalSinceTaken:(NSTimeInterval)timeInterval;

/* Notification response */
+ (void)logNotificationOpenedWithType:(DFPushNotifType)type;
+ (void)logNotificationViewItemOpened:(NSString *)type notifDate:(NSDate *)notifDate;

/* Inviting */
+ (void)logInviteComposeFinishedWithResult:(MessageComposeResult)result
                  presentingViewController:(UIViewController *)presentingViewController;

/* Contacts */
+ (void)logAddContactCompletedWithResult:(NSString *)result;

/* external urls */
+ (void)logURLOpenedAppWithURL:(NSURL *)url
                   otherParams:(NSDictionary *)otherParams;

/* Card processing */
+ (void)logIncomingCardProcessedWithResult:(NSString *)result
                               actionType:(NSString *)actionType;
+ (void)logOutgoingCardProcessedWithSuggestion:(DFPeanutFeedObject *)suggestion
                                        result:(NSString *)result
                               actionType:(NSString *)actionType;

+ (void)logHomeButtonTapped:(NSString *)buttonName
         incomingBadgeCount:(NSUInteger)incomingCount
         outgoingBadgeCount:(NSUInteger)outgoingCount;

+ (void)logOtherCardType:(NSString *)type
     processedWithResult:(NSString *)result
              actionType:(NSString *)actionType;

// incoming/outgoing (done)
// detail photo view (done)
// top buttons tapped (done)
// interstitial (

//like and comment origins



#pragma mark - Utilities

+ (NSString *)bucketStringForObjectCount:(NSUInteger)objectCount;
+ (NSString *)actionStringForType:(DFPeanutActionType)action;


@end
