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
#import "Flurry/Flurry.h"
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFUser.h"
#import "DFUserPeanutAdapter.h"
#import "DFFirstTimeSetupViewController.h"
#import "DFLocationPinger.h"
#import "HockeySDK.h"
#import "DFBackgroundRefreshController.h"
#import <RestKit/RestKit.h>
#import "DFAppInfo.h"
#import "DFPeanutPushTokenAdapter.h"


@interface AppDelegate ()

@property (nonatomic, retain) DFPeanutPushTokenAdapter *pushTokenAdapter;
            
@end

@implementation AppDelegate
            

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self configureLogs];
  [self configureHockey];
  [self configureFlurry];
  
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [self requestPushNotifs];
  
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
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"f4cd14764b2b5695063cdfc82e5097f6"];
  [[BITHockeyManager sharedHockeyManager] startManager];
  [[BITHockeyManager sharedHockeyManager].authenticator
   authenticateInstallation];
}

- (void)configureFlurry
{
#ifdef DEBUG
  [Flurry startSession:@"DT9THCNBPHCST3B6BG4C"];
  [Flurry setLogLevel:FlurryLogLevelDebug];
#else
  [Flurry startSession:@"6JYTNZB8ZZNJXN8DP4Q"];
#endif
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
  if (![NSThread isMainThread]) {
    [self performSelectorOnMainThread:@selector(showMainView)
                           withObject:nil
                        waitUntilDone:NO];
    return;
  }
  
  [DFPhotoStore sharedStore];
  [self checkForAndRequestLocationAccess];
  [self performForegroundOperations];
  self.window.rootViewController = [[RootViewController alloc] init];
  [[DFBackgroundRefreshController sharedBackgroundController] startBackgroundRefresh];
}

- (void)performForegroundOperations
{
  DDLogInfo(@"Strand app %@ became active.", [DFAppInfo appInfoString]);
  if ([self isAppSetupComplete]) {
    [[DFUploadController sharedUploadController] uploadPhotos];
    [[DFBackgroundRefreshController sharedBackgroundController] performFetch];
  }
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

- (void)requestPushNotifs
{
  DDLogInfo(@"Requesting push notifications.");
  [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
   (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
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
  
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [self performForegroundOperations];
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

-(void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  
  UIBackgroundFetchResult result = [[DFBackgroundRefreshController sharedBackgroundController]
                                    performFetch];
  completionHandler(result);
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	if (!self.pushTokenAdapter) self.pushTokenAdapter = [[DFPeanutPushTokenAdapter alloc] init];
  
  DFBuildType buildType = DFBuildTypeDebug;
  #ifndef DEBUG
    buildType = DFBuildTypeAdHoc;
  #endif
  
  [self.pushTokenAdapter registerAPNSToken:deviceToken forBuildType:buildType completionBlock:^(BOOL success) {
    if (success) {
      DDLogInfo(@"Push token successfuly registered with server.");
    } else {
      DDLogInfo(@"Push token FAILED to register with server");
    }
  }];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	DDLogWarn(@"Failed to get push token, error: %@", error);
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
