//
//  DFAnalytics.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAnalytics.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AddressBook/AddressBook.h>
#import "NSDictionary+DFJSON.h"
#import "LocalyticsSession.h"
#import "DFDefaultsStore.h"
#import "DFPeanutPushNotification.h"
#import "DFPeanutFeedObject.h"



@interface DFAnalytics()

@property (atomic, retain) NSString *inProgressQueryString;
@property (atomic, retain) NSString *inProgressQuerySuggestions;
@property (atomic, retain) NSDate *inProgressQueryStart;

@end

@implementation DFAnalytics

/*** Generic Keys and values ***/

NSString* const ActionTypeKey = @"actionType";
NSString* const DFAnalyticsActionTypeSwipe = @"swipe";
NSString* const NumberKey = @"number";

NSString* const SizeInKBKey = @"sizeInKB";
NSString* const ResultKey = @"result";
NSString* const DFAnalyticsValueResultSuccess = @"success";
NSString* const DFAnalyticsValueResultFailure = @"failure";
NSString* const DFAnalyticsValueResultInvalidInput = @"invalidInput";
NSString* const DFAnalyticsValueResultAborted = @"aborted";
NSString* const ParentViewControllerKey = @"parentView";
NSString* const SLatencyKey = @"SecondsLatency";


NSString* const DFAnalyticsIsErrorKey = @"isError";


//Generic value
NSString* const NewValueKey = @"newValue";

/*** Event specific keys ***/

//Controller logging
NSString* const ControllerViewedEventSuffix = @"Viewed";
NSString* const ControllerClassKey = @"controllerClass";

// Create Strand
NSString* const CreateStrandEvent = @"CreateStrand";

// Photo actions
NSString* const PhotoSavedEvent = @"PhotoSaved";
NSString* const PhotoDeletedEvent = @"PhotoDeleted";
NSString* const PhotoLikedEvent = @"PhotoLiked";
NSString* const PhotoActionEvent = @"PhotoAction";

// Notifications
NSString* const NotificationOpenedEvent = @"NotificationOpened";
NSString* const NotificationTypeKey = @"notificationType";
NSString* const NotificationsViewItemOpened = @"NotificationsViewItemOpened";

// App Setup
NSString* const SetupPhoneNumberEntered = @"SetupPhoneNumberEntered";
NSString* const SetupSMSCodeEntered = @"SetupSMSCodeEntered";
NSString* const SetupLocationCompleted = @"SetupLocationCompleted";
NSString* const SetupContactsCompleted = @"SetupContactsCompleted";
NSString* const SetupPhotosCompleted = @"SetupPhotosCompleted";

// Invites
NSString* const InviteUserFinshed = @"InviteUserFinished";

//Push notifs
NSString* const PermissionChangedEvent = @"PermissionChanged";
NSString* const NotificationsChangedEvent = @"NotificationsChanged";
NSString* const PermissionTypeKey = @"permissionType";
NSString* const StateChangeKey = @"stateChange";
NSString* const ValueChangeKey = @"valueChange";

NSString* const PhotoAgeKey = @"photoAge";
NSString* const PostAge = @"postAge";


static DFAnalytics *defaultLogger;

+ (void)StartAnalyticsSession
{
#ifdef DEBUG
  [[LocalyticsSession shared]
   LocalyticsSession:@"7790abca456e78bb24ebdbb-8e7455f6-fe36-11e3-9fb0-009c5fda0a25"];
  // [[LocalyticsSession shared] setLoggingEnabled:YES];
#else
  [[LocalyticsSession shared]
   LocalyticsSession:@"dd0a7a0a4c9c1a5a602904f-285e4dea-5c55-11e4-a3a4-005cf8cbabd8"];
  [[LocalyticsSession shared] setEnableHTTPS:YES];
#endif
  [[LocalyticsSession shared] enableHTTPS];
  [DFAnalytics ResumeAnalyticsSession];
}

+ (void)ResumeAnalyticsSession
{
  [[LocalyticsSession shared] resume];
  [[LocalyticsSession shared] upload];
}

+ (void)CloseAnalyticsSession
{
  [[LocalyticsSession shared] close];
  [[LocalyticsSession shared] upload];
}


+ (void)logEvent:(NSString *)eventName withParameters:(NSDictionary *)parameters
{
  [[LocalyticsSession shared] tagEvent:eventName attributes:parameters];
}

+ (void)logEvent:(NSString *)eventName
{
  [[LocalyticsSession shared] tagEvent:eventName];
}


+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params
{
  NSString *screenName = [self screenNameForControllerViewed:viewController];
  [[LocalyticsSession shared] tagScreen:screenName];
  [DFAnalytics logEvent:[NSString stringWithFormat:@"%@Viewed",screenName] withParameters:params];
}

+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params
{
  // Do nothing for now
}

+ (NSString *)screenNameForControllerViewed:(UIViewController *)viewController
{
  NSMutableString *className = [[viewController.class description] mutableCopy];
  //remove DF
  [className replaceOccurrencesOfString:@"DF"
                             withString:@""
                                options:0
                                  range:(NSRange){0,2}];
  //remove ViewController
  [className replaceOccurrencesOfString:@"ViewController"
                             withString:@""
                                options:0
                                  range:(NSRange) {0, className.length}];
  
  
  return className ? className : @"";
}

+ (void)logCreateStrandFlowCompletedWithResult:(NSString *)result
                             numPhotosSelected:(NSUInteger)numPhotos
                             numPeopleSelected:(NSUInteger)numPeople
                                     extraInfo:(NSDictionary *)extraInfo
{
  NSMutableDictionary *parameters = [@{ResultKey : result,
                                       @"photosSelected" : [self bucketStringForObjectCount:numPhotos],
                                       @"peopleSelected" : [self bucketStringForObjectCount:numPeople],
                                       } mutableCopy];
  [parameters addEntriesFromDictionary:extraInfo];
  DDLogVerbose(@"%@ create strand attrs: %@", self.class, parameters);
  [self logEvent:CreateStrandEvent withParameters:parameters];
}

+ (void)logPhotoSavedWithResult:(NSString *)result
{
  [DFAnalytics logEvent:PhotoSavedEvent withParameters:@{ResultKey: result}];
}

+ (void)logNotificationOpenedWithType:(DFPushNotifType)type
{
   [DFAnalytics logEvent:NotificationOpenedEvent
         withParameters:@{
                          NotificationTypeKey: [DFPeanutPushNotification pushNotifTypeToString:type],
                          }];
}

+ (void)logNotificationViewItemOpened:(NSString *)type notifDate:(NSDate *)notifDate
{
  [DFAnalytics logEvent:NotificationsViewItemOpened
         withParameters:@{
                          @"type": type,
                          @"age" : [self bucketStringForTimeInternval:[[NSDate date]
                                                                       timeIntervalSinceDate:notifDate]]
                          }];
}

+ (void)logPhotoDeletedWithResult:(NSString *)result
           timeIntervalSinceTaken:(NSTimeInterval)timeInterval
{
  [DFAnalytics logEvent:PhotoDeletedEvent withParameters:@{
                                                           ResultKey: result,
                                                           PhotoAgeKey: [self bucketStringForTimeInternval:timeInterval]
                                                           }];
}

+ (void)logPhotoLikePressedWithNewValue:(BOOL)isOn
                                 result:(NSString *)result
                             actionType:(DFUIActionType)actionType
                 timeIntervalSinceTaken:(NSTimeInterval)timeInterval
{
  [DFAnalytics logEvent:PhotoLikedEvent withParameters:@{
                                                         NewValueKey: @(isOn),
                                                         ResultKey: result,
                                                         @"ActionType" : actionType,
                                                         PhotoAgeKey : [self bucketStringForTimeInternval:timeInterval]
                                                         }];
}


+ (void)logPhotoActionTaken:(DFPeanutActionType)action
                     result:(NSString *)result
                photoObject:(DFPeanutFeedObject *)photo
                postsObject:(DFPeanutFeedObject *)postsObject
{
  NSTimeInterval takenInterval = [[NSDate date] timeIntervalSinceDate:photo.time_taken];
  NSTimeInterval postedInterval = [[NSDate date] timeIntervalSinceDate:postsObject.time_stamp];
  NSArray *photosInPosts = [postsObject leafNodesFromObjectOfType:DFFeedObjectPhoto];
  NSArray *comments = [photo actionsOfType:DFPeanutActionComment forUser:0];
  NSArray *likes = [photo actionsOfType:DFPeanutActionFavorite forUser:0];
  
  [DFAnalytics logEvent:PhotoActionEvent
         withParameters:@{
                          ResultKey: result,
                          @"ActionType" : [self actionStringForType:action],
                          PhotoAgeKey : [self bucketStringForTimeInternval:takenInterval],
                          PostAge : [self bucketStringForTimeInternval:postedInterval],
                          @"PhotosInThread" : [self bucketStringForObjectCount:photosInPosts.count],
                          @"NumComments" : [self bucketStringForObjectCount:comments.count],
                          @"NumLikes" : [self bucketStringForObjectCount:likes.count],
                          }];
}

+ (NSString *)actionStringForType:(DFPeanutActionType)action
{
  if (action == DFPeanutActionFavorite) {
    return @"Favorite";
  } else if (action == DFPeanutActionComment) {
    return @"Comment";
  } else {
    return [@(action) stringValue];
  }
}


+ (void)logSetupPhoneNumberEnteredWithResult:(NSString *)result
{
  [DFAnalytics logEvent:SetupPhoneNumberEntered withParameters:@{ResultKey: result}];
}

+ (void)logSetupSMSCodeEnteredWithResult:(NSString *)result
{
  [DFAnalytics logEvent:SetupSMSCodeEntered withParameters:@{ResultKey: result}];
}

+ (void)logSetupPhotosCompletedWithResult:(NSString *)result
{
  [DFAnalytics logEvent:SetupPhotosCompleted withParameters:@{ResultKey: result}];
}

+ (void)logSetupLocationCompletedWithResult:(NSString *)result
                        userTappedLearnMore:(BOOL)didTapLearnMore
{
  [DFAnalytics logEvent:SetupLocationCompleted
         withParameters:@{
                          ResultKey: result,
                          @"didPressLearnMore" : [NSNumber numberWithBool:didTapLearnMore]
                          }];
}

+ (void)logSetupContactsCompletedWithABPermission:(int)status
                                 numAddedManually:(NSUInteger)numAddedManually
{
  [DFAnalytics logEvent:SetupContactsCompleted
         withParameters:@{
                          DFPermissionContacts: [self.class stateFromABAuthStatus:status],
                          @"numAddedManually": @(numAddedManually),
                          }];
}

+ (void)logPermission:(DFPermissionType)permission
  changedWithOldState:(DFPermissionStateType)oldState
             newState:(DFPermissionStateType)newState
{
  if (oldState == nil) oldState = DFPermissionStateNotRequested;
  if ([oldState isEqual:newState]) return;
  [DFAnalytics logEvent:PermissionChangedEvent
         withParameters:@{
                          PermissionTypeKey: permission,
                          StateChangeKey: [DFAnalytics stringForOldState:oldState toNewState:newState]
                          }];
}

+ (void)logInviteComposeFinishedWithResult:(MessageComposeResult)result
                  presentingViewController:(UIViewController *)presentingViewController

{
  NSString *resultString;
  if (result == MessageComposeResultCancelled) {
    resultString = DFAnalyticsValueResultAborted;
  } else if (result == MessageComposeResultFailed) {
    resultString = DFAnalyticsValueResultFailure;
  } else if (result == MessageComposeResultSent) {
    resultString = DFAnalyticsValueResultSuccess;
  } else {
    resultString = @"Unknown";
  }
  
  [DFAnalytics logEvent:InviteUserFinshed withParameters:@{
                                                           ResultKey: resultString,
                                                           ParentViewControllerKey: [DFAnalytics screenNameForControllerViewed:presentingViewController]
                                                           }];
}

+ (void)logRemoteNotifsChangedFromOldNotificationType:(UIRemoteNotificationType)oldType
                                                  newType:(UIRemoteNotificationType)newType
{
  NSString *oldValue = [DFAnalytics stringForUIRemoteNotifType:oldType];
  NSString *newValue = [DFAnalytics stringForUIRemoteNotifType:newType];
  if ([oldValue isEqual:newValue]) return;
  
  [DFAnalytics logEvent:NotificationsChangedEvent
         withParameters:@{
                          PermissionTypeKey: DFPermissionRemoteNotifications,
                          ValueChangeKey:[self stringForOldState:oldValue toNewState:newValue]
                            }];
}

+ (void)logUserNotifsChangedFromOldNotificationType:(UIUserNotificationType)oldType
                                              newType:(UIUserNotificationType)newType
{
  NSString *oldValue = [DFAnalytics stringForUIUserNotifType:oldType];
  NSString *newValue = [DFAnalytics stringForUIUserNotifType:newType];
  if ([oldValue isEqual:newValue]) return;
  
  [DFAnalytics logEvent:NotificationsChangedEvent
         withParameters:@{
                          PermissionTypeKey: DFPermissionRemoteNotifications,
                          ValueChangeKey:[self stringForOldState:oldValue toNewState:newValue]
                          }];
}

+ (NSString *)stringForOldState:(NSString *)oldState toNewState:(NSString *)newState
{
  return [NSString stringWithFormat:@"%@ -> %@",
          oldState ? oldState : @"None",
          newState ? newState : @"None"
          ];
}

+ (NSString *)stringForUIRemoteNotifType:(UIRemoteNotificationType)type;
{
  if (type == UIRemoteNotificationTypeNone) return @"None";

  NSMutableString *valueString = [[NSMutableString alloc] init];
  if (type | UIRemoteNotificationTypeBadge) {
    [valueString appendString:@"Badge"];
  }
  if (type | UIRemoteNotificationTypeSound) {
    [valueString appendString:@"Sound"];
  }
  if (type | UIRemoteNotificationTypeAlert) {
    [valueString appendString:@"Alert"];
  }
  
  return valueString;
}

+ (NSString *)stringForUIUserNotifType:(UIUserNotificationType)type
{
  if (type == UIUserNotificationTypeNone) return @"None";
  
  NSMutableString *valueString = [[NSMutableString alloc] init];
  if (type | UIUserNotificationTypeBadge) {
    [valueString appendString:@"Badge"];
  }
  if (type | UIUserNotificationTypeSound) {
    [valueString appendString:@"Sound"];
  }
  if (type | UIUserNotificationTypeAlert) {
    [valueString appendString:@"Alert"];
  }
  
  return valueString;
}


+ (void)logPermissionsChanges
{
  // Photos
  DFPermissionStateType oldPhotoState = [DFDefaultsStore stateForPermission:DFPermissionPhotos];
  DFPermissionStateType currentPhotoState =
  [self.class stateFromAssetAuthStatus:[ALAssetsLibrary authorizationStatus]];
  [self lookForAndRecordPermissionChangeForType:DFPermissionPhotos
                                   oldState:oldPhotoState currentState:currentPhotoState];
  
  // Contacts
  DFPermissionStateType oldContactsState = [DFDefaultsStore stateForPermission:DFPermissionContacts];
  DFPermissionStateType currentContactsState =
  [self.class stateFromABAuthStatus:ABAddressBookGetAuthorizationStatus()];
  [self lookForAndRecordPermissionChangeForType:DFPermissionContacts
                                   oldState:oldContactsState
                               currentState:currentContactsState];
}

+ (void)lookForAndRecordPermissionChangeForType:(DFPermissionType)permissionType
                                   oldState:(DFPermissionStateType)oldState
                                   currentState:(DFPermissionStateType)newState
{
  if (oldState == nil) oldState = DFPermissionStateNotRequested;
  if ([oldState isEqual:newState]) {
    return;
  }
  
  DDLogInfo(@"%@ permission change for %@ found: %@",
            [self.class description],
            permissionType,
            [self stringForOldState:oldState toNewState:newState]);
  // The defaults store will automatically call back to DFAnalytics to log the state change
  [DFDefaultsStore setState:newState forPermission:permissionType];
}

+ (DFPermissionStateType)stateFromAssetAuthStatus:(ALAuthorizationStatus)status
{
  if (status == ALAuthorizationStatusAuthorized) {
    return DFPermissionStateGranted;
  } else if (status == ALAuthorizationStatusDenied) {
    return DFPermissionStateDenied;
  } else if (status == ALAuthorizationStatusRestricted) {
    return DFPermissionStateRestricted;
  } else { //if (status == ALAuthorizationStatusNotDetermined)
    return DFPermissionStateNotRequested;
  }
}

+ (DFPermissionStateType)stateFromABAuthStatus:(ABAuthorizationStatus)status
{
  if (status == kABAuthorizationStatusAuthorized) {
    return DFPermissionStateGranted;
  } else if (status == kABAuthorizationStatusDenied) {
    return DFPermissionStateDenied;
  } else if (status == kABAuthorizationStatusRestricted) {
    return DFPermissionStateRestricted;
  } else { //if (status == kABAuthorizationStatusNotDetermined)
    return DFPermissionStateNotRequested;
  }
}


+ (void)logAddContactCompletedWithResult:(NSString *)result
{
  [self logEvent:@"AddManualContact" withParameters:@{ResultKey: result}];
}

#pragma mark - Bucket Value helpers

+ (NSString *)bucketStringForTimeInternval:(NSTimeInterval)timeInterval
{
  if (timeInterval < 60) {
    return @"< 1m";
  } else if (timeInterval < 60 * 5) {
    return @"1-5m";
  } else if (timeInterval < 60 * 10) {
    return @"5-10m";
  } else if (timeInterval < 60 * 30) {
    return @"10-30m";
  } else if (timeInterval < 60 * 60) {
    return @"30m-1h";
  } else if (timeInterval < 60 * 60 * 2) {
    return @"1-2h";
  } else if (timeInterval < 60 * 60 * 12) {
    return @"2-12h";
  } else if (timeInterval < 60 * 60 * 24) {
    return @"12-24h";
  } else if (timeInterval < 60 * 60 * 24 * 3) {
    return @"1-3d";
  } else if (timeInterval < 60 * 60 * 24 * 7) {
    return @"3d-1w";
  } else if (timeInterval < 60 * 60 * 24 * 30) {
    return @"1w-1M";
  } else if (timeInterval < 60 * 60 * 24 * 60) {
    return @"1-2M";
  }
  
  return @">2M";
}

+ (NSString *)bucketStringForObjectCount:(NSUInteger)numPhotos
{
  if (numPhotos == 0) return @"0";
  if (numPhotos == 1) return @"1";
  if (numPhotos == 2) return @"2";
  if (numPhotos <= 5) return @"3-5";
  if (numPhotos <= 10) return @"6-10";
  if (numPhotos <= 20) return @"11-20";
  if (numPhotos <= 50) return @"21-50";
  if (numPhotos <= 100) return @"51-100";
  if (numPhotos <= 500) return @"101-500";
  if (numPhotos <= 1000) return @"501-1000";
  if (numPhotos <= 2000) return @"1001-2000";
  if (numPhotos <= 4000) return @"2001-4000";
  if (numPhotos <= 8000) return @"4001-8000";
  return @">8000";
}

+ (NSString *)bucketStringForKBPS:(double)KBPS
{
  if (KBPS < 0.1) return @"<0.1";
  if (KBPS <= 1.0) return @"0.1-1";
  if (KBPS <= 10.0) return @"1-10";
  if (KBPS <= 50.0) return @"10-50";
  if (KBPS <= 100.0) return @"50-100";
  if (KBPS <= 200.0) return @"100-200";
  if (KBPS <= 500.0) return @"200-500";
  if (KBPS <= 1000.0) return @"500-1000";
  return @">1000.0";
}



@end
