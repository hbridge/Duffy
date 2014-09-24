//
//  DFPushNotificationsManager.h
//  Strand
//
//  Created by Henry Bridge on 8/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFPushNotificationsManager : NSObject <UIAlertViewDelegate>

+ (DFPushNotificationsManager *)sharedManager;

- (void)promptForPushNotifsIfNecessary;
+ (void)requestPushNotifsPermission;
+ (void)refreshPushToken;
+ (void)registerDeviceToken:(NSData *)data;
+ (void)registerFailedWithError:(NSError *)error;
+ (void)registerUserNotificationSettings:(UIUserNotificationSettings *)settings;

@end
