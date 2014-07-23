//
//  DFStatusBarNotificationManager.h
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFToastNotificationManager : NSObject

typedef enum {
  DFStatusUploadError,
  DFFeedRefreshError,
} DFToastNotificationType;


+ (DFToastNotificationManager *)sharedInstance;

- (void)showNotificationWithType:(DFToastNotificationType)notificationType;
- (void)showPhotoNotificationWithString:(NSString *)string;
- (void)showNotificationWithString:(NSString *)string timeout:(NSTimeInterval)timeout;
- (void)showErrorWithTitle:(NSString *)title subTitle:(NSString *)subtitle;

@end
