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
#import "DFStrandConstants.h"
#import "DFCameraRollChangeManager.h"
#import "DFNavigationController.h"
#import "DFContactSyncManager.h"
#import "DFSocketsManager.h"


@interface AppDelegate ()

@property (nonatomic, retain) DFPeanutPushTokenAdapter *pushTokenAdapter;
            
@end

@implementation AppDelegate
            

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self configureLogs];
  [self configureHockey];

  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [self.window makeKeyAndVisible];
  
  if ([application applicationState] != UIApplicationStateBackground) {
    // only create views etc if we're not being launched in the background
    [self createRootViewController];
  }
  
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
#ifdef DEBUG
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"f4cd14764b2b5695063cdfc82e5097f6"];
#else
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"81845532ce7ca873cdfce8e43f8abce9"];
#endif
  
  [[BITHockeyManager sharedHockeyManager] startManager];
  [[BITHockeyManager sharedHockeyManager].authenticator
   authenticateInstallation];
}

- (BOOL)isAppSetupComplete
{
  return  ([[DFUser currentUser] userID]
           && ![[DFUser currentUser] userID] == 0
           && [DFDefaultsStore  stateForPermission:DFPermissionLocation]
           && [DFDefaultsStore  stateForPermission:DFPermissionContacts]
           && ![[DFDefaultsStore stateForPermission:DFPermissionLocation]
                isEqual:DFPermissionStateNotRequested]
           && ![[DFDefaultsStore stateForPermission:DFPermissionContacts]
                isEqual:DFPermissionStateNotRequested]);
}

- (void)showFirstTimeSetup
{
  DFFirstTimeSetupViewController *setupViewController = [[DFFirstTimeSetupViewController alloc] init];
  self.window.rootViewController = [[DFNavigationController alloc]
                                    initWithRootViewController:setupViewController];
}

- (void)firstTimeSetupComplete
{
  [self showMainView];
  [self performForegroundOperations];
}

- (void)createRootViewController
{
  if (![self isAppSetupComplete]) {
    [self showFirstTimeSetup];
  } else if (![self isAuthTokenValid]) {
    [self resetApplication];
  } else {
    [self showMainView];
  }

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
  DDLogInfo(@"AppDelegate performForegroundOperation");
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
    if ([self isAppSetupComplete]) {
      [[DFUploadController sharedUploadController] uploadPhotos];
      [[DFStrandsManager sharedStrandsManager] performFetch:nil];
      [[DFSocketsManager sharedManager] initNetworkCommunication];
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandRefreshRemoteUIRequestedNotificationName
       object:self];
    }
  } else {
    DDLogInfo(@"%@ performForegroundOperations called but appState = %d",
              @"AppDelegate",
              (int)[[UIApplication sharedApplication] applicationState]);
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
  [DFDefaultsStore setState:newNotifsState forPermission:DFPermissionRemoteNotifications];
  NSNumber *lastNotifType = [DFDefaultsStore lastNotificationType];
  UIRemoteNotificationType currentNotifTypes = [[UIApplication sharedApplication]
                                                enabledRemoteNotificationTypes];
  [DFAnalytics logRemoteNotifsChangedFromOldNotificationType:lastNotifType.intValue
                                                     newType:currentNotifTypes];
}

- (void)applicationWillResignActive:(UIApplication *)application {
  DDLogInfo(@"AppDelegate appWillResignActive");
  [DFAnalytics CloseAnalyticsSession];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  DDLogInfo(@"AppDelegate appDidenterBackground");
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[DFPhotoStore sharedStore] saveContext];
  [DFAnalytics CloseAnalyticsSession];
  
  if ([self isAppSetupComplete]) {
    [DFAnalytics logPermissionsChanges];
    [[DFContactSyncManager sharedManager] sync];
  }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  DDLogInfo(@"AppDelegate for %@ appWillEnterForeground.", [DFAppInfo appInfoString]);
  if (!self.window.rootViewController) [self createRootViewController];
  [DFAnalytics ResumeAnalyticsSession];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  DDLogInfo(@"AppDelegate for %@ appDidBecomeActive.", [DFAppInfo appInfoString]);
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
  [self registerPushTokenForData:[NSData new]];
  if (error.code == 3010) {
    [self checkForAndLogNotifsChange:DFPermissionStateUnavailable];
  } else {
    [self checkForAndLogNotifsChange:DFPermissionStateDenied];
  }
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
  DDLogInfo(@"App received notification: %@",
               userInfo.description);
  DFPeanutPushNotification *pushNotif = [[DFPeanutPushNotification alloc] initWithUserInfo:userInfo];
  if ([application applicationState] == UIApplicationStateBackground){
    if (pushNotif.contentAvailable && pushNotif.isUpdateLocationRequest)
    {
      [[DFBackgroundLocationManager sharedBackgroundLocationManager]
       backgroundUpdateWithCompletionHandler:completionHandler];
    }
  } else if ([application applicationState] == UIApplicationStateInactive) {
    // This is the state that the note is received in if the user is swiping a notification
    if (pushNotif.screenToShow == DFScreenNone) return;
    
    UIViewController *rootViewController = self.window.rootViewController;
    if ([rootViewController.class isSubclassOfClass:[RootViewController class]]) {
      if (pushNotif.photoID) {
        [(RootViewController *)self.window.rootViewController showPhotoWithID:pushNotif.photoID];
      } else if (pushNotif.screenToShow == DFScreenCamera) {
        [(RootViewController *)self.window.rootViewController showCamera];
      } else if (pushNotif.screenToShow == DFScreenGallery) {
        [(RootViewController *)self.window.rootViewController showGallery];
      }
    }
    [DFAnalytics logNotificationOpenedWithType:pushNotif.type];
  } else if ([application applicationState] == UIApplicationStateActive) {
    if ([pushNotif.message isNotEmpty]) {
      [[DFToastNotificationManager sharedInstance] showPhotoNotificationWithString:pushNotif.message];
    }    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandRefreshRemoteUIRequestedNotificationName
     object:self];
  }
  
  if (completionHandler) completionHandler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  NSDate *startDate = [NSDate date];
  DDLogInfo(@"Strand background app refresh called at %@", startDate);
  UIBackgroundFetchResult result = [[DFCameraRollChangeManager sharedManager] backgroundChangeScan];
  DDLogInfo(@"Strand background app refresh finishing after %.02f seconds with result: %d",
            [[NSDate date] timeIntervalSinceDate:startDate],
            (int)result);
  completionHandler(result);
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
