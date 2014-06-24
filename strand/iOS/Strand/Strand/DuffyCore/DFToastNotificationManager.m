//
//  DFStatusBarNotificationManager.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFToastNotificationManager.h"
#import "CRToast.h"

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
                            kCRToastTextAlignmentKey : @(NSTextAlignmentLeft),
                            kCRToastBackgroundColorKey : [UIColor orangeColor],
                            kCRToastAnimationInTypeKey : @(CRToastAnimationTypeLinear),
                            kCRToastAnimationOutTypeKey : @(CRToastAnimationTypeLinear),
                            kCRToastAnimationInDirectionKey : @(CRToastAnimationDirectionTop),
                            kCRToastAnimationOutDirectionKey : @(CRToastAnimationDirectionTop),
                            kCRToastNotificationPresentationTypeKey : @(CRToastPresentationTypeCover),
                            kCRToastTextMaxNumberOfLinesKey : @(0),
                            kCRToastSubtitleTextMaxNumberOfLinesKey : @(0),
                            kCRToastSubtitleTextAlignmentKey : @(NSTextAlignmentLeft),
                            kCRToastNotificationTypeKey: @(CRToastTypeNavigationBar),
                            kCRToastImageKey: [UIImage imageNamed:@"Assets/Icons/WarningIcon.png"],
                          
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
  [CRToastManager showNotificationWithOptions:options
                              completionBlock:^{
                              }];
}

- (void)showNotificationWithString:(NSString *)string timeout:(NSTimeInterval)timeout
{
  NSMutableDictionary *options = [[self defaultNotificationOptions] mutableCopy];
  options[kCRToastTimeIntervalKey] = @(timeout);
  options[kCRToastTextKey] = string;
  
  [CRToastManager showNotificationWithOptions:options
                              completionBlock:^{
                              }];
}
@end
