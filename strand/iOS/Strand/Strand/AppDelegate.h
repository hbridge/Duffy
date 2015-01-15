//
//  AppDelegate.h
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (void)resetApplication;
- (void)firstTimeSetupComplete;
- (void)firstTimeSetupUserIdStepCompleteWithSyncTimestamp:(NSDate *)date;
- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
       forceCheckin:(BOOL)forceCheckin;
@end

