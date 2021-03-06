//
//  DFStatusBarNotificationManager.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFToastNotificationManager.h"
#import "CRToast.h"
#import <AudioToolbox/AudioServices.h>
#import "DFStrandConstants.h"
#import "DFPeanutAction.h"
#import "DFPeanutFeedDataManager.h"

@implementation DFToastNotificationManager

static DFToastNotificationManager *defaultManager;

+ (DFToastNotificationManager *)sharedInstance {
    if (!defaultManager) {
        defaultManager = [[super allocWithZone:nil] init];
    }
    return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedInstance];
}

- (id)init
{
    self = [super init];
    if (self) {
      
    }
    return self;
}

- (NSDictionary *)defaultNotificationOptions
{
  NSDictionary *options = @{
                            kCRToastTextAlignmentKey : @(NSTextAlignmentCenter),
                            kCRToastBackgroundColorKey : [DFStrandConstants defaultBackgroundColor],
                            kCRToastTextColorKey : [DFStrandConstants defaultBarForegroundColor],
                            kCRToastAnimationInTypeKey : @(CRToastAnimationTypeLinear),
                            kCRToastAnimationOutTypeKey : @(CRToastAnimationTypeLinear),
                            kCRToastAnimationInDirectionKey : @(CRToastAnimationDirectionTop),
                            kCRToastAnimationOutDirectionKey : @(CRToastAnimationDirectionTop),
                            kCRToastNotificationPresentationTypeKey : @(CRToastPresentationTypeCover),
                            kCRToastTextMaxNumberOfLinesKey : @(0),
                            kCRToastSubtitleTextMaxNumberOfLinesKey : @(0),
                            kCRToastSubtitleTextAlignmentKey : @(NSTextAlignmentLeft),
                            kCRToastNotificationTypeKey: @(CRToastTypeNavigationBar),
                            kCRToastInteractionRespondersKey: @[[DFToastNotificationManager
                                                                 dismissInteractionHandler]],
                            kCRToastStatusBarStyleKey: @(UIStatusBarStyleLightContent),
                            };
  
  return options;
}

- (void)showNotificationWithType:(DFToastNotificationType)notificationType
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (notificationType == DFStatusUploadError) {
      [self showErrorWithTitle:@"An upload error occurred. Your photo will be uploaded later."
                      subTitle:nil];
    } else if (notificationType == DFFeedRefreshError) {
      [self showErrorWithTitle:@"Couldn't reload feed. Please try again later."
                      subTitle:nil];
    }
  });
}

- (void)showErrorWithTitle:(NSString *)title subTitle:(NSString *)subtitle
{
  NSMutableDictionary *options = [[self defaultNotificationOptions] mutableCopy];

  options[kCRToastTextAlignmentKey] = @(NSTextAlignmentLeft);
  options[kCRToastTimeIntervalKey] = @(5.0);
  options[kCRToastTextKey] = title;
  if (subtitle) options[kCRToastSubtitleTextKey] = subtitle;
  options[kCRToastImageKey] = [UIImage imageNamed:@"Assets/Icons/WarningIcon.png"];
  options[kCRToastInteractionRespondersKey] = @[[self.class dismissInteractionHandler]];
  [CRToastManager showNotificationWithOptions:options
                              completionBlock:^{
                              }];
  AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

- (void)showNotificationWithString:(NSString *)string timeout:(NSTimeInterval)timeout
{
  NSMutableDictionary *options = [[self defaultNotificationOptions] mutableCopy];
  options[kCRToastTextAlignmentKey] = @(NSTextAlignmentLeft);
  options[kCRToastTimeIntervalKey] = @(timeout);
  options[kCRToastTextKey] = string;
  options[kCRToastInteractionRespondersKey] = @[[self.class dismissInteractionHandler]];
  
  [CRToastManager showNotificationWithOptions:options
                              completionBlock:^{
                              }];
  AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

- (void)showNotificationForPush:(DFPeanutPushNotification *)pushNotif
                        handler:(DFNoticationOpenedHandler)openedHandler
{
  NSMutableDictionary *options = [[self defaultNotificationOptions] mutableCopy];
  options[kCRToastTextAlignmentKey] = @(NSTextAlignmentLeft);
  options[kCRToastTimeIntervalKey] = @(5.0);
  options[kCRToastTextKey] = pushNotif.message ? pushNotif.message : @"";
  options[kCRToastImageKey] = [UIImage imageNamed:@"Assets/Icons/PhotoNotificationIcon.png"];
  
  options[kCRToastInteractionRespondersKey] = @[[self.class dismissInteractionHandler],
                                                [self.class handlerWithOpenedHandler:openedHandler
                                                                        forPushNotif:pushNotif],
                                                 ];
  
  [CRToastManager showNotificationWithOptions:options
                              completionBlock:^{
                              }];
  AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}


+ (CRToastInteractionResponder *)handlerWithOpenedHandler:(DFNoticationOpenedHandler)handler
                    forPushNotif:(DFPeanutPushNotification *)pushNotif
{
  return
  [CRToastInteractionResponder
   interactionResponderWithInteractionType:CRToastInteractionTypeTapOnce
   automaticallyDismiss:YES
   block:^(CRToastInteractionType interactionType) {
     handler(pushNotif);
   }];
}

+ (CRToastInteractionResponder *)dismissInteractionHandler
{
  return [CRToastInteractionResponder
          interactionResponderWithInteractionType:CRToastInteractionTypeSwipe
          automaticallyDismiss:YES
          block:^(CRToastInteractionType interactionType) {
            DDLogVerbose(@"CRToast notification dismissed by user.");
          }];
}

@end
