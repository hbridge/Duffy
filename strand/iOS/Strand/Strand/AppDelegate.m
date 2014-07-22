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
#import "HockeySDK.h"
#import "DFStrandsManager.h"
#import <RestKit/RestKit.h>
#import "DFAppInfo.h"
#import "DFPeanutPushTokenAdapter.h"
#import "DFAnalytics.h"
#import "DFToastNotificationManager.h"
#import "DFBackgroundLocationManager.h"
#import "DFDefaultsStore.h"
#import "DFTypedefs.h"
#import "DFPeanutPushNotification.h"
#import "NSString+DFHelpers.h"


@interface AppDelegate ()

@property (nonatomic, retain) DFPeanutPushTokenAdapter *pushTokenAdapter;
            
@end

@implementation AppDelegate
            

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self configureLogs];
  [self configureHockey];
  
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

   if (![self isAppSetupComplete]) {
    [self showFirstTimeSetup];
  } else if (![self isAuthTokenValid]) {
    [self resetApplication];
  } else {
    [self showMainView];
   }
  
  [self.window makeKeyAndVisible];
  
  if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
    [self application:application didReceiveRemoteNotification:
     launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]];
  }

  return YES;
}

- (void)configureLogs
{
  [DDLog addLogger:[DDASLLogger sharedInstance]];
  [DDLog addLogger:[DDTTYLogger sharedInstance]];
  
  DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
  fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
  fileLogger.logFileManager.maximumNumberOfLogFiles = 3; // 3 days of files
  
  // To simulate the amount of log data saved, use the release log level for the fileLogger
  [DDLog addLogger:fileLogger withLogLevel:DFRELEASE_LOG_LEVEL];

#ifdef DEBUG
  //RKLogConfigureByName("RestKit/Network", RKLogLevelTrace);
  //RKLogConfigureByName("RestKit/ObjectMapping", RKLogLevelTrace);
  RKLogConfigureByName("RestKit/Network", RKLogLevelError);
#else
  RKLogConfigureByName("RestKit/Network", RKLogLevelError);
#endif
}

- (void)configureHockey
{
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"81845532ce7ca873cdfce8e43f8abce9"];
  [[BITHockeyManager sharedHockeyManager] startManager];
  [[BITHockeyManager sharedHockeyManager].authenticator
   authenticateInstallation];
  
  #ifdef DEBUG
  [[BITHockeyManager sharedHockeyManager] setDisableUpdateManager:YES];
  #endif
}

- (BOOL)isAppSetupComplete
{
  return  ([[DFUser currentUser] userID]
           && ![[DFUser currentUser] userID] == 0);
}

- (void)showFirstTimeSetup
{
  DFFirstTimeSetupViewController *setupViewController = [[DFFirstTimeSetupViewController alloc] init];
  self.window.rootViewController = [[UINavigationController alloc]
                                    initWithRootViewController:setupViewController];
}

- (void)showMainView
{
  if (![NSThread isMainThread]) {
    [self performSelectorOnMainThread:@selector(showMainView)
                           withObject:nil
                        waitUntilDone:NO];
    return;
  }
  
  [DFPhotoStore sharedStore];
  [self requestPushNotifs];
  [self performForegroundOperations];
  self.window.rootViewController = [[RootViewController alloc] init];
  [[DFBackgroundLocationManager sharedBackgroundLocationManager]
   startUpdatingOnSignificantLocationChange];
}

- (BOOL)isAuthTokenValid
{
  NSString *authToken = [[DFUser currentUser] authToken];
  // for now, if there is an authToken at all, we'll consider it valid
  if (authToken && ![authToken isEqualToString:@""]) return YES;
  
  return NO;
}

- (void)performForegroundOperations
{
  DDLogInfo(@"Strand app %@ became active.", [DFAppInfo appInfoString]);
  if ([self isAppSetupComplete]) {
    [[DFUploadController sharedUploadController] uploadPhotos];
    [[DFStrandsManager sharedStrandsManager] performFetch];
  }
}

- (void)requestPushNotifs
{
  [self checkForAndLogNotifsChange:[DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications]];
  DDLogInfo(@"Requesting push notifications.");
  [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
   (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
}

- (void)checkForAndLogNotifsChange:(DFPermissionStateType)newNotifsState
{
  if (!newNotifsState || [newNotifsState isEqualToString:DFPermissionStateNotRequested]) return;
  
  DFPermissionStateType lastNotifsState = [DFDefaultsStore stateForPermission:DFPermissionRemoteNotifications];
  NSNumber *lastNotifType = [DFDefaultsStore lastNotificationType];
  UIRemoteNotificationType currentNotifTypes = [[UIApplication sharedApplication]
                                                enabledRemoteNotificationTypes];
  
  if ((![lastNotifsState isEqualToString:newNotifsState]) ||
      (lastNotifType.intValue != (int)currentNotifTypes)) {
    DDLogInfo(@"Notification types changed. Old State:%@ New State: %@, Old Type:%d New Type:%d",
              lastNotifsState, newNotifsState, lastNotifType.intValue, (int)currentNotifTypes);
    [DFAnalytics logRemoteNotifsChangedWithOldState:lastNotifsState
                                           newState:newNotifsState
                                oldNotificationType:lastNotifType.intValue
                                            newType:currentNotifTypes];

    [DFDefaultsStore setLastNotificationType:currentNotifTypes];
    [DFDefaultsStore setState:newNotifsState forPermission:DFPermissionRemoteNotifications];
  }
}

- (void)applicationWillResignActive:(UIApplication *)application {
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  [DFAnalytics CloseAnalyticsSession];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[DFPhotoStore sharedStore] saveContext];
  [DFAnalytics CloseAnalyticsSession];
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  [DFAnalytics ResumeAnalyticsSession];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [DFAnalytics StartAnalyticsSession];
  [self performForegroundOperations];
}

- (void)applicationWillTerminate:(UIApplication *)application {
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[DFPhotoStore sharedStore] saveContext];
  [DFAnalytics CloseAnalyticsSession];
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	[self registerPushTokenForData:deviceToken];
  [self checkForAndLogNotifsChange:DFPermissionStateGranted];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	DDLogWarn(@"Failed to get push token, error: %@", error);
  NSData *errorData = [[NSData alloc] init];
  [self registerPushTokenForData:errorData];
  [self checkForAndLogNotifsChange:DFPermissionStateDenied];
}

- (void)registerPushTokenForData:(NSData *)data
{
  if (!self.pushTokenAdapter) self.pushTokenAdapter = [[DFPeanutPushTokenAdapter alloc] init];
  
  [self.pushTokenAdapter registerAPNSToken:data  completionBlock:^(BOOL success) {
    if (success) {
      DDLogInfo(@"Push token successfuly registered with server.");
    } else {
      DDLogInfo(@"Push token FAILED to register with server");
    }
  }];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
  DDLogInfo(@"Foreground notification being forwarded to background notif handler.");
  [self application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:nil];
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  DDLogVerbose(@"App received notification dict: %@",
               userInfo.description);
  DFPeanutPushNotification *pushNotif = [[DFPeanutPushNotification alloc] initWithUserInfo:userInfo];
  if ([application applicationState] == UIApplicationStateBackground && pushNotif.isUpdateLocationRequest){
    if (pushNotif.contentAvailable)
    {
      [[DFBackgroundLocationManager sharedBackgroundLocationManager]
       backgroundUpdateWithCompletionHandler:completionHandler];
    }
  } else if ([application applicationState] == UIApplicationStateInactive) {
    // This is the state that the note is received in if the user is swiping a notification
    if (pushNotif.screenToShow == DFScreenNone) return;
    
    UIViewController *rootViewController = self.window.rootViewController;
    if ([rootViewController.class isSubclassOfClass:[RootViewController class]]) {
      if (pushNotif.screenToShow == DFScreenCamera) {
        [(RootViewController *)self.window.rootViewController showCamera];
      } else if (pushNotif.screenToShow == DFScreenGallery) {
        [(RootViewController *)self.window.rootViewController showGallery];
      }
    }
    [DFAnalytics logNotificationOpened:[NSString stringWithFormat:@"%d", pushNotif.screenToShow]];
  } else if ([application applicationState] == UIApplicationStateActive) {
    if ([pushNotif.message isNotEmpty]) {
      [[DFToastNotificationManager sharedInstance] showPhotoNotificationWithString:pushNotif.message];
    }
    [[DFStrandsManager sharedStrandsManager] performFetch];
  }
  
  if (completionHandler) completionHandler(UIBackgroundFetchResultNewData);
}

- (void)resetApplication
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DDLogInfo(@"Resetting application.");
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"Logged Out"
                          message:@"You have been logged out of Strand.  Please re-verify your phone number."
                          delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    
    
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
