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
                            kCRToastBackgroundColorKey : [DFStrandConstants mainColor],
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
                                                                 dismissInteractionHandler]]
                            };
  
  return options;
}

- (void)showNotificationWithType:(DFToastNotificationType)notificationType
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (notificationType == DFStatusUploadError) {
      [self showErrorWithTitle:@"Couldn't Share Photos"
                      subTitle:@"An upload error occurred, please try again later."];
    }
  });
}

- (void)showErrorWithTitle:(NSString *)title subTitle:(NSString *)subtitle
{
  NSMutableDictionary *options = [[self defaultNotificationOptions] mutableCopy];

  options[kCRToastTimeIntervalKey] = @(5.0);
  options[kCRToastTextKey] = title;
  options[kCRToastSubtitleTextKey] = subtitle;
  options[kCRToastImageKey] = [UIImage imageNamed:@"Assets/Icons/WarningIcon.png"];
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
  
  [CRToastManager showNotificationWithOptions:options
                              completionBlock:^{
                              }];
  AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

- (void)showPhotoNotificationWithString:(NSString *)string
{
  NSMutableDictionary *options = [[self defaultNotificationOptions] mutableCopy];
  options[kCRToastTextAlignmentKey] = @(NSTextAlignmentLeft);
  options[kCRToastTimeIntervalKey] = @(10);
  options[kCRToastTextKey] = string;
  options[kCRToastImageKey] = [UIImage imageNamed:@"Assets/Icons/PhotoNotificationIcon.png"];
  
  [CRToastManager showNotificationWithOptions:options
                              completionBlock:^{
                              }];
  AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}


+ (id)dismissInteractionHandler
{
  return [CRToastInteractionResponder
          interactionResponderWithInteractionType:CRToastInteractionTypeAll
          automaticallyDismiss:YES
          block:^(CRToastInteractionType interactionType) {
            DDLogVerbose(@"CRToast notification dismissed by user.");
          }];
}

@end
