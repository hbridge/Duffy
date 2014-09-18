//
//  AppDelegate.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <CocoaLumberjack/DDTTYLogger.h>
#import <CocoaLumberjack/DDASLLogger.h>
#import <CocoaLumberjack/DDFileLogger.h>
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFUser.h"
#import "DFUserPeanutAdapter.h"
#import "DFCreateAccountViewController.h"
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
#import "DFCameraRollSyncManager.h"
#import "DFNavigationController.h"
#import "DFContactSyncManager.h"
#import "DFSocketsManager.h"
#import "DFContactsStore.h"
#import "DFPushNotificationsManager.h"
#import "DFFeedViewController.h"
#import "DFSettingsViewController.h"
#import "DFCreateStrandViewController.h"
#import "DFTopBarController.h"
#import "DFActivityFeedViewController.h"
#import "DFGalleryViewController.h"


@interface AppDelegate ()

@property (nonatomic, retain) UITabBarController *tabBarController;
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
  
#if TARGET_IPHONE_SIMULATOR
  NSLog(@"Simulator build running from: %@", [ [NSBundle mainBundle] bundleURL] );
#endif

  
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
           && ![[DFDefaultsStore stateForPermission:DFPermissionLocation]
                isEqual:DFPermissionStateNotRequested]
           && ![[DFDefaultsStore stateForPermission:DFPermissionContacts]
                isEqual:DFPermissionStateNotRequested]);
}

- (void)showFirstTimeSetup
{
  DFCreateAccountViewController *setupViewController = [[DFCreateAccountViewController alloc] init];
  self.window.rootViewController = [[DFNavigationController alloc]
                                    initWithRootViewController:setupViewController];
}


/*
 This gets called as soon as the last of the first time setup steps area complete.
 Right now, that is after the location permission is done.  This is called directly from the
 controller.
 */
- (void)firstTimeSetupComplete
{
  [self showMainView];
  [self performForegroundOperations];
  [self showCreateStrand];
}

/*
  Put things here that should be kicked off as soon as we have a user ID.
  This is called directly from the SMSAuth controller.
 
  This is only called on first time setup, so all these calls should also exist in other areas like
    performForegroundOperations and all the calls should be idempotent.
 */
- (void)firstTimeSetupUserIdStepComplete
{
  // Start up the socket server so we can start getting real time updates for when there's new data on the server
  [[DFSocketsManager sharedManager] initNetworkCommunication];
  
  // We're doing this because this view isn't necessarily created yet, so create it and have it load up its data
  [[DFCreateStrandViewController sharedViewController] refreshFromServer];
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
  
  DFActivityFeedViewController *strandsFeedViewCotnroller = [[DFActivityFeedViewController alloc] init];
  DFGalleryViewController *galleryviewController = [[DFGalleryViewController alloc] init];
  DFSettingsViewController *settingsController = [[DFSettingsViewController alloc] init];

  self.tabBarController = [[UITabBarController alloc] init];
  self.tabBarController.viewControllers =
  @[[[DFNavigationController alloc] initWithRootViewController:strandsFeedViewCotnroller],
    [[DFNavigationController alloc] initWithRootViewController:galleryviewController],
    [[DFNavigationController alloc] initWithRootViewController:settingsController]
    ];
  
  for (UINavigationController *vc in self.tabBarController.viewControllers) {
    vc.tabBarItem.imageInsets = vc.tabBarItem.imageInsets = UIEdgeInsetsMake(5.5, 0, -5.5, 0);
  }
  self.tabBarController.tabBar.selectedImageTintColor = [DFStrandConstants strandRed];
  //self.tabBarController.tabBar.selectedImageTintColor = [UIColor whiteColor];
  self.tabBarController.tabBar.translucent = NO;
  
  self.window.rootViewController = self.tabBarController;
  
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
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
    if ([self isAppSetupComplete]) {
      [[DFCameraRollSyncManager sharedManager] sync];
      [[DFUploadController sharedUploadController] uploadPhotos];
      [[DFStrandsManager sharedStrandsManager] performFetch:nil];
      [[DFSocketsManager sharedManager] initNetworkCommunication];
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
       object:self];
      
      // We're doing this because this view isn't necessarily created yet, so create it and have it load up its data
      [[DFCreateStrandViewController sharedViewController] refreshFromServer];
    }
  } else {
    DDLogInfo(@"%@ performForegroundOperations called but appState = %d",
              @"AppDelegate",
              (int)[[UIApplication sharedApplication] applicationState]);
  }
}

- (void)applicationWillResignActive:(UIApplication *)application {
  [DFAnalytics CloseAnalyticsSession];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[DFPhotoStore sharedStore] saveContext];
  [[DFContactsStore sharedStore] saveContext];
  [DFAnalytics CloseAnalyticsSession];
  
  if ([self isAppSetupComplete]) {
    [DFAnalytics logPermissionsChanges];
    [[DFContactSyncManager sharedManager] sync];
  }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  if (!self.window.rootViewController) [self createRootViewController];
  [DFAnalytics ResumeAnalyticsSession];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [DFAnalytics StartAnalyticsSession];
  [self performForegroundOperations];
  [DFPushNotificationsManager refreshPushToken];
}

- (void)applicationWillTerminate:(UIApplication *)application {
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[DFPhotoStore sharedStore] saveContext];
  [[DFContactsStore sharedStore] saveContext];
  [DFAnalytics CloseAnalyticsSession];
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	[DFPushNotificationsManager registerDeviceToken:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
  [DFPushNotificationsManager registerFailedWithError:error];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
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
    
    if (pushNotif.photoID) {
      //TODO disabled for now
    } else if (pushNotif.screenToShow == DFScreenCamera) {
      //[(RootViewController *)self.window.rootViewController showCamera];
      // TODO disabled for now
    } else if (pushNotif.screenToShow == DFScreenGallery) {
      // TODO disabled for now
    }
    
    [DFAnalytics logNotificationOpenedWithType:pushNotif.type];
  } else if ([application applicationState] == UIApplicationStateActive) {
    if ([pushNotif.message isNotEmpty]) {
      [[DFToastNotificationManager sharedInstance] showNotificationForPush:pushNotif];
    }    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
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

- (void)showCreateStrand
{
  DFCreateStrandViewController *vc = [DFCreateStrandViewController sharedViewController];
  vc.showAsFirstTimeSetup = YES;
  
  [self.tabBarController presentViewController:[[DFNavigationController alloc] initWithRootViewController:vc]
                                      animated:YES
                                    completion:nil];
}



@end
