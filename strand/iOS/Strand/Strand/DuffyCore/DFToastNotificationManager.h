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
} DFToastNotificationType;


+ (DFToastNotificationManager *)sharedInstance;

- (void)showNotificationWithType:(DFToastNotificationType)notificationType;

- (void)showNotificationWithString:(NSString *)string timeout:(NSTimeInterval)timeout;

@end
