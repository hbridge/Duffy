//
//  DFAppDelegate.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAppDelegate.h"
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDFileLogger.h>
#import "Flurry/Flurry.h"
#import "DFPhotoStore.h"
#import "DFSettingsViewController.h"
#import "DFSearchViewController.h"
#import "DFCameraRollSyncController.h"
#import "DFPhotoNavigationControllerViewController.h"
#import "DFPhotoImageCache.h"
#import "DFUser.h"
#import <HockeySDK/HockeySDK.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <RestKit/RestKit.h>
#import "DFLocationPinger.h"
#import "DFAppInfo.h"
#import "DFUploadController.h"
#import "DFUserPeanutAdapter.h"
#import "DFIntroPageViewController.h"




@interface DFAppDelegate()

@end

@implementation DFAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  
  [self configureLogs];
  DDLogVerbose(@"CocoaLumberjack active.");
  
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"7e0628b85696cfd8bd471f9906fbc79f"];
  [[BITHockeyManager sharedHockeyManager].authenticator setIdentificationType:BITAuthenticatorIdentificationTypeDevice];
  [[BITHockeyManager sharedHockeyManager] startManager];
  
  [Flurry setCrashReportingEnabled:NO];
#ifdef DEBUG
  [Flurry startSession:@"YFWFVHZXVX8ZCWX643B9"];
  //[Flurry setLogLevel:FlurryLogLevelDebug];
  
  //RKLogConfigureByName("RestKit/Network", RKLogLevelTrace);
  //RKLogConfigureByName("RestKit/ObjectMapping", RKLogLevelTrace);
  RKLogConfigureByName("RestKit/Network", RKLogLevelError);
#else
  [Flurry startSession:@"MMJXFR6J7J5Y3YB9MK6N"];
#endif

  // create the shared store, this will automatically run integrity checks
  [DFPhotoStore sharedStore];
  

  if (![self isAppSetupComplete]) {
    [self showFirstTimeSetup];
  } else {
    [self startUserIDCheck];
    [self showLoggedInUserTabs];
  }
  
  self.window.backgroundColor = [UIColor whiteColor];
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


- (BOOL)isAppSetupComplete
{
  return  ([[DFUser currentUser] userID]
           && ![[DFUser currentUser] userID] == 0
           &&  [ALAssetsLibrary authorizationStatus] == ALAuthorizationStatusAuthorized
           && ![[DFLocationPinger sharedInstance] canAskForLocationPermission]);
}

- (void)showFirstTimeSetup
{
  UIStoryboard *introStoryboard = [UIStoryboard storyboardWithName:@"DFIntro" bundle:nil];
  UIViewController *vc = [introStoryboard instantiateInitialViewController];
  self.window.rootViewController = vc;
}


- (void)showLoggedInUserTabs
{
  // Set the unique userID for logging
  [Flurry setUserID:[NSString stringWithFormat:@"%llu",[[DFUser currentUser] userID]]];
  [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
  
  //make sure our singletons are set up.
  [DFPhotoStore sharedStore];
  [DFUploadController sharedUploadController];
  [self startCameraRollSync];
  
  DFSearchViewController *searchViewController = [[DFSearchViewController alloc] init];
  UINavigationController *searchViewNav = [[DFPhotoNavigationControllerViewController alloc] initWithRootViewController:searchViewController];
  
    [[self window] setRootViewController:searchViewNav];
}

- (void)startCameraRollSync
{
  [[DFCameraRollSyncController sharedSyncController] asyncSyncToCameraRoll];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  DDLogInfo(@"Duffy resigned active.");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  DDLogInfo(@"Duffy entered background.");
  [[DFPhotoStore sharedStore] saveContext];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  DDLogInfo(@"%@ became active.", [DFAppInfo appInfoString]);
  if (![self isAppSetupComplete]) return;
  
  [self startCameraRollSync];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  DDLogInfo(@"Duffy applicationWillTerminate");
  
  if (![self isAppSetupComplete]) return;
  [[DFPhotoStore sharedStore] saveContext];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
  DDLogWarn(@"DFAppDelegate memory warning.");
  [[DFPhotoImageCache sharedCache] emptyCache];
}


- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
  if( [[BITHockeyManager sharedHockeyManager].authenticator handleOpenURL:url
                                                        sourceApplication:sourceApplication
                                                               annotation:annotation]) {
    return YES;
  }
  
  /* Your own custom URL handlers */
  
  return NO;
}


- (void)resetApplication
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DDLogInfo(@"Resetting application.");
    [[DFCameraRollSyncController sharedSyncController] cancelSyncOperations];
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
