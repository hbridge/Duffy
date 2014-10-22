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
#import <HockeySDK/HockeySDK.h>
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFUser.h"
#import "DFUserPeanutAdapter.h"
#import "DFCreateAccountViewController.h"
#import "DFStrandsManager.h"
#import <RestKit/RestKit.h>
#import "DFAppInfo.h"
#import "DFNotificationSharedConstants.h"
#import "DFPeanutPushTokenAdapter.h"
#import "DFAnalytics.h"
#import "DFToastNotificationManager.h"
#import "DFBackgroundLocationManager.h"
#import "DFDefaultsStore.h"
#import "DFTypedefs.h"
#import "DFPeanutPushNotification.h"
#import "NSString+DFHelpers.h"
#import "DFStrandConstants.h"
#import "DFCameraRollSyncManager.h"
#import "DFNavigationController.h"
#import "DFContactSyncManager.h"
#import "DFSocketsManager.h"
#import "DFContactsStore.h"
#import "DFPushNotificationsManager.h"
#import "DFFeedViewController.h"
#import "DFSettingsViewController.h"
#import "DFStrandSuggestionsViewController.h"
#import "DFTopBarController.h"
#import "DFInboxViewController.h"
#import "DFAllStrandsGalleryViewController.h"
#import "DFFriendsViewController.h"
#import "DFUserInfoManager.h"
#import "DFImageDownloadManager.h"
#import "DFImageStore.h"
#import "DFSwapViewController.h"


@interface AppDelegate () <BITHockeyManagerDelegate> {}

@property (nonatomic) DDFileLogger *fileLogger;

@property (nonatomic, retain) UITabBarController *tabBarController;
@property (nonatomic, retain) DFPeanutPushTokenAdapter *pushTokenAdapter;
@property (nonatomic, retain) DFInboxViewController *inboxViewController;

// These are used to track the state of background fetch signals from the syncer and uploader
@property (nonatomic, assign) BOOL backgroundSyncHasFinished;
@property (nonatomic, assign) BOOL backgroundSyncAndUploaderHaveFinished;
@property (nonatomic, assign) BOOL backgroundSyncInProgress;
@property (nonatomic, retain) NSDate * firstRunSyncTimestamp;
@property (nonatomic, retain) NSTimer *backgroundSyncCancelUploadsTimer;
@property (nonatomic, retain) NSTimer *backgroundSyncReturnTimer;

@end

@implementation AppDelegate

const NSUInteger MinValidAccountId = 650;

// This is used to store the completion handler during our background syncs
void (^_completionHandler)(UIBackgroundFetchResult);

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

  // These are used for background syncs
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(backgroundCameraRollSyncFinished)
                                               name:DFCameraRollSyncCompleteNotificationName
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(backgroundUploaderFinished)
                                               name:DFUploaderCompleteNotificationName
                                             object:nil];
  
  return YES;
}

- (void)configureLogs
{
  [DDLog addLogger:[DDASLLogger sharedInstance]];
  [DDLog addLogger:[DDTTYLogger sharedInstance]];
  
  self.fileLogger = [[DDFileLogger alloc] init];
  self.fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
  self.fileLogger.logFileManager.maximumNumberOfLogFiles = 3; // 3 days of files
  
  // To simulate the amount of log data saved, use the release log level for the fileLogger
  [DDLog addLogger:self.fileLogger withLogLevel:DFRELEASE_LOG_LEVEL];

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
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"f4cd14764b2b5695063cdfc82e5097f6"
                                                         delegate:self];
#else
  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"81845532ce7ca873cdfce8e43f8abce9"
                                                         delegate:self];
#endif
  
  [[BITHockeyManager sharedHockeyManager] startManager];
  [[BITHockeyManager sharedHockeyManager].authenticator
   authenticateInstallation];
}

- (BOOL)isAppSetupComplete
{
  return  ([[DFUser currentUser] userID]
           && ![[DFUser currentUser] userID] == 0
           && ![[DFDefaultsStore stateForPermission:DFPermissionContacts]
                isEqual:DFPermissionStateNotRequested]);
}

- (void)showFirstTimeSetup
{
  [DFPhotoStore resetStore]; // make sure the photo store is clean
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
  // If we got a timestamp to sync to, then lets sync to that first
  if (self.firstRunSyncTimestamp) {
    // If we already have a sync going, cancel and do the one with the timestamp.
    // If we don't, just do the sync to a timestamp
    if ([[DFCameraRollSyncManager sharedManager] isSyncInProgress]) {
      [[DFCameraRollSyncManager sharedManager] cancelSyncOperations];
      [[DFCameraRollSyncManager sharedManager] syncAroundDate:self.firstRunSyncTimestamp withCompletionBlock:^(NSDictionary *objectIDsToChanges){
        [self firstRunSyncComplete:objectIDsToChanges];
      }];
      [[DFCameraRollSyncManager sharedManager] sync];
    } else {
      [[DFCameraRollSyncManager sharedManager] syncAroundDate:self.firstRunSyncTimestamp withCompletionBlock:^(NSDictionary *objectIDsToChanges){
        [self firstRunSyncComplete:objectIDsToChanges];
      }];
    }
  }
  
  [self showMainView];
  [self performForegroundOperations];
  
  // Show the Inbox
  self.tabBarController.selectedIndex = 0;
}

/*
 * This should be called after we have synced the initial set of photos (if there's an invite, upload photos around
 * that date and time first).
 * This then tells the server that we're good to go.
 */
- (void)firstRunSyncComplete:(NSDictionary *)objectsIds
{
  [[DFUserInfoManager sharedManager] setFirstTimeSyncCount:[NSNumber numberWithInteger:objectsIds.allKeys.count]];
}
/*
  Put things here that should be kicked off as soon as we have a user ID.
  This is called directly from the SMSAuth controller.
 
  This is only called on first time setup, so all these calls should also exist in other areas like
    performForegroundOperations and all the calls should be idempotent.
 */
- (void)firstTimeSetupUserIdStepCompleteWithSyncTimestamp:(NSDate *)date
{
  self.firstRunSyncTimestamp = date;
  DDLogVerbose(@"Setting firstRunSyncTimestamp to: %@", self.firstRunSyncTimestamp);
  
  // Start up the socket server so we can start getting real time updates for when there's new data on the server
  [[DFSocketsManager sharedManager] initNetworkCommunication];
  
  // We're doing this because this view isn't necessarily created yet, so create it and have it load up its data
  [[DFStrandSuggestionsViewController sharedViewController] refreshFromServer];
}

- (void)createRootViewController
{
  if (![self isAppSetupComplete]) {
    [self showFirstTimeSetup];
  } else if (![self isUserValid]) {
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
  
  self.inboxViewController = [[DFInboxViewController alloc] init];
  DFSwapViewController *swapViewController = [[DFSwapViewController alloc] init];
  DFFriendsViewController *friendsViewController = [[DFFriendsViewController alloc] init];
  self.tabBarController = [[UITabBarController alloc] init];
  self.tabBarController.viewControllers =
  @[[[DFNavigationController alloc] initWithRootViewController:self.inboxViewController],
    [[DFNavigationController alloc] initWithRootViewController:swapViewController],
    [[DFNavigationController alloc] initWithRootViewController:friendsViewController],
    ];
  
  for (UINavigationController *vc in self.tabBarController.viewControllers) {
    vc.tabBarItem.imageInsets = vc.tabBarItem.imageInsets = UIEdgeInsetsMake(5.5, 0, -5.5, 0);
  }
  self.tabBarController.tabBar.selectedImageTintColor = [DFStrandConstants strandRed];
  //self.tabBarController.tabBar.selectedImageTintColor = [UIColor whiteColor];
  self.tabBarController.tabBar.translucent = NO;
  
  self.tabBarController.selectedIndex = 1;
  self.window.rootViewController = self.tabBarController;
}

- (BOOL)isUserValid
{
  if ([[DFUser currentUser] userID] < MinValidAccountId) {
    return NO;
  }

  return YES;
}

- (void)performForegroundOperations
{
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
    DDLogInfo(@"%@ became active", [DFAppInfo appInfoString]);
    if ([self isAppSetupComplete]) {
      [[DFCameraRollSyncManager sharedManager] sync];
      [[DFContactSyncManager sharedManager] sync];
      [[DFUploadController sharedUploadController] uploadPhotos];
      [[DFStrandsManager sharedStrandsManager] performFetch:nil];
      [[DFSocketsManager sharedManager] initNetworkCommunication];
      [[DFImageDownloadManager sharedManager] fetchNewImages];
      [[DFImageStore sharedStore] loadDownloadedImagesCache];
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
       object:self];
      
      // We're doing this because this view isn't necessarily created yet, so create it and have it load up its data
      [[DFStrandSuggestionsViewController sharedViewController] refreshFromServer];
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

- (void)application:(UIApplication *)application
didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
  [DFPushNotificationsManager registerUserNotificationSettings:notificationSettings];
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
  [[DFPushNotificationsManager sharedManager]
   handleNotificationForApp:application
   userInfo:userInfo
   fetchCompletionHandler:completionHandler];
}

- (void)backgroundCameraRollSyncFinished
{
  if (self.backgroundSyncInProgress == YES) {
    self.backgroundSyncHasFinished = YES;
  }
}

/*
 * Called during a background refresh when the uploader has completed a pass.
 * This doesn't necessarily mean we're done, we want to wait for the syncer to finish.
 * The syncer tells the uploader to do one last pass after it finishes, and thats what we're listening for.
 * 
 * Once we're done, cancel the timers we set in performFetchWithCompletionHandler.
 */
- (void)backgroundUploaderFinished
{
  if (self.backgroundSyncInProgress == YES) {
    if (self.backgroundSyncHasFinished && self.backgroundSyncAndUploaderHaveFinished == NO) {
      DDLogVerbose(@"Uploader finished and so has sync, so returning");
      self.backgroundSyncAndUploaderHaveFinished = YES;
      self.backgroundSyncInProgress = NO;
      
      [self.backgroundSyncCancelUploadsTimer invalidate];
      self.backgroundSyncCancelUploadsTimer = nil;
      
      [self.backgroundSyncReturnTimer invalidate];
      self.backgroundSyncReturnTimer = nil;
      
      _completionHandler(UIBackgroundFetchResultNewData);
    } else if (self.backgroundSyncAndUploaderHaveFinished == YES) {
      DDLogVerbose(@"Uploader finished but we should have already returned...ignoring");
    } else {
      DDLogVerbose(@"Uploader finished but sync hasn't yet...waiting");
    }
  }
}
- (void)backgroundSyncCancelUploads
{
  DDLogInfo(@"Telling uploads to stop");
  [[DFUploadController sharedUploadController] cancelUploads:YES];
}

- (void)backgroundSyncReturn
{
  DDLogInfo(@"Leaving background app refresh at %@", [NSDate date]);
  self.backgroundSyncInProgress = NO;
  _completionHandler(UIBackgroundFetchResultNewData);
}

/*
 * This is called every few minutes or so as a background process.
 * We have 30 seconds to return, so put in a timer to enforce that.
 */
- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  NSDate *startDate = [NSDate date];
  DDLogInfo(@"Strand background app refresh called at %@", startDate);

  // Copy the completion handler for use later
  _completionHandler = [completionHandler copy];
  
  // We must set these everytime since state is saved
  self.backgroundSyncHasFinished = NO;
  self.backgroundSyncAndUploaderHaveFinished = NO;
  self.backgroundSyncInProgress = YES;
  
  // Now we want to setup a backup system incase our uploads take more than 30 seconds.
  int64_t delayInSeconds = 29;

  self.backgroundSyncCancelUploadsTimer = [NSTimer scheduledTimerWithTimeInterval:delayInSeconds - 3
                                                        target:self
                                                      selector:@selector(backgroundSyncCancelUploads)
                                                      userInfo:nil
                                                       repeats:NO];
  
  self.backgroundSyncReturnTimer = [NSTimer scheduledTimerWithTimeInterval:delayInSeconds
                                                                           target:self
                                                                         selector:@selector(backgroundSyncReturn)
                                                                         userInfo:nil
                                                                          repeats:NO];
  
  // Need to do this to have the class start listening to signals
  [DFUploadController sharedUploadController];
  [[DFCameraRollSyncManager sharedManager] sync];
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
    
    
    [[DFUploadController sharedUploadController] cancelUploads:NO];
    [DFPhotoStore resetStore];
    [[DFContactsStore sharedStore] resetStore];
    
    // clear user defaults
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    
    DDLogInfo(@"App reset complete.  Showing first time setup.");
    [self showFirstTimeSetup];
  });
}

- (void)showStrandWithID:(DFStrandIDType)strandID
              completion:(void(^)(void))completion
{
  DDLogInfo(@"%@ showStrandWithID:%@", self.class, @(strandID));
  [self.inboxViewController showStrandPostsForStrandID:strandID completion:completion];

}


#pragma mark - BITCrashManagerDelegate

- (NSString *)applicationLogForCrashManager:(BITCrashManager *)crashManager {
  NSString *description = [self getLogFilesContentWithMaxSize:10000]; // 10K bytes should be enough!
  if ([description length] == 0) {
    return nil;
  } else {
    return description;
  }
}

// get the log content with a maximum byte size
- (NSString *) getLogFilesContentWithMaxSize:(NSInteger)maxSize {
  NSMutableString *description = [NSMutableString string];
  
  NSArray *sortedLogFileInfos = [[_fileLogger logFileManager] sortedLogFileInfos];
  NSInteger count = [sortedLogFileInfos count];
  
  // we start from the last one
  for (NSInteger index = count - 1; index >= 0; index--) {
    DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:index];
    
    NSData *logData = [[NSFileManager defaultManager] contentsAtPath:[logFileInfo filePath]];
    if ([logData length] > 0) {
      NSString *result = [[NSString alloc] initWithBytes:[logData bytes]
                                                  length:[logData length]
                                                encoding: NSUTF8StringEncoding];
      
      [description appendString:result];
    }
  }
  
  if ([description length] > maxSize) {
    description = (NSMutableString *)[description substringWithRange:NSMakeRange([description length]-maxSize-1, maxSize)];
  }
  
  return description;
}


@end
