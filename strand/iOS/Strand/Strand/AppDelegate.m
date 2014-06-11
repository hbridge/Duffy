//
//  AppDelegate.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "RootViewController.h"
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDFileLogger.h>
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFUser.h"
#import "DFUserPeanutAdapter.h"
#import "DFFirstTimeSetupViewController.h"
#import "DFLocationPinger.h"

@interface AppDelegate ()
            
@end

@implementation AppDelegate
            

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self configureLogs];
  
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];
  
  if (![self isAppSetupComplete]) {
    [self showFirstTimeSetup];
  } else {
    [self startUserIDCheck];
    [self showMainView];
  }
  
  [self.window makeKeyAndVisible];

  return YES;
}

- (void)configureLogs
{
  [DDLog addLogger:[DDASLLogger sharedInstance]];
  [DDLog addLogger:[DDTTYLogger sharedInstance]];
  
  DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
  fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
  fileLogger.logFileManager.maximumNumberOfLogFiles = 7; // 7 days of files
  
  // To simulate the amount of log data saved, use the release log level for the fileLogger
  [DDLog addLogger:fileLogger withLogLevel:DFRELEASE_LOG_LEVEL];
}

- (void)startUserIDCheck
{
  DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
  [userAdapter fetchUserForDeviceID:[[DFUser currentUser] deviceID] withSuccessBlock:^(DFUser *user) {
    if (!user || user.userID != [[DFUser currentUser] userID]) {
      DDLogWarn(@"Server uid:%llu, phone uid:%llu.  Requesting reset.", user.userID, [[DFUser currentUser ]userID]);
      [self resetApplication];
    }
  } failureBlock:nil];
}

- (void)getUserID
{
  DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
  [userAdapter fetchUserForDeviceID:[[DFUser currentUser] deviceID]
                   withSuccessBlock:^(DFUser *user) {
                     if (user) {
                       DDLogInfo(@"Got user: %@", user.description);
                       [[DFUser currentUser] setUserID:user.userID];
                     } else {
                       // the request succeeded, but the user doesn't exist, we have to create it
                       [userAdapter createUserForDeviceID:[[DFUser currentUser] deviceID]
                                               deviceName:[[DFUser currentUser] deviceName]
                                         withSuccessBlock:^(DFUser *user) {
                                           DDLogInfo(@"Created user: %@", user.description);
                                           [[DFUser currentUser] setUserID:user.userID];
                                         }
                                             failureBlock:^(NSError *error) {
                                               DDLogWarn(@"Create user failed: %@", error.localizedDescription);
                                             }];
                     }
                   } failureBlock:^(NSError *error) {
                     DDLogWarn(@"Get user failed: %@", error.localizedDescription);
                   }];
}

- (BOOL)isAppSetupComplete
{
  return  ([[DFUser currentUser] userID]
           && ![[DFUser currentUser] userID] == 0);
}



- (void)showFirstTimeSetup
{
  DFFirstTimeSetupViewController *setupViewController = [[DFFirstTimeSetupViewController alloc] init];
  self.window.rootViewController = setupViewController;
}

- (void)showMainView
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [DFPhotoStore sharedStore];
    [self checkForAndRequestLocationAccess];
    [[DFUploadController sharedUploadController] uploadPhotos];
    self.window.rootViewController = [[RootViewController alloc] init];
  });
}

- (void)checkForAndRequestLocationAccess
{
  if ([[DFLocationPinger sharedInstance] haveLocationPermisison]) {
    DDLogInfo(@"Already have location access.");
  } else if ([[DFLocationPinger sharedInstance] canAskForLocationPermission])
  {
    [[DFLocationPinger sharedInstance] askForLocationPermission];
  }
}

- (void)applicationWillResignActive:(UIApplication *)application {
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)resetApplication
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DDLogInfo(@"Resetting application.");
    [[DFUploadController sharedUploadController] cancelUploads];
    [[DFPhotoStore sharedStore] resetStore];
    
    // clear user defaults
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    
    DDLogInfo(@"App reset complete.  Showing first time setup.");
    [self showFirstTimeSetup];
  });

}

@end
