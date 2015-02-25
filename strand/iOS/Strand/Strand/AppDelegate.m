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
#import <Facebook-iOS-SDK/FacebookSDK/FacebookSDK.h>
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFUser.h"
#import "DFPeanutUserAdapter.h"
#import "DFNUXFlowViewController.h"
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
#import "DFSettingsViewController.h"
#import "DFFriendsViewController.h"
#import "DFUserInfoManager.h"
#import "DFImageDownloadManager.h"
#import "DFImageDiskCache.h"
#import "DFPeanutFeedDataManager.h"
#import "DFGalleryViewController.h"
#import "DFContactDataManager.h"
#import "DFCardsPageViewController.h"
#import "DFHomeViewController.h"
#import "DFSettings.h"

@interface AppDelegate () <BITHockeyManagerDelegate> {}

@property (nonatomic) DDFileLogger *fileLogger;

@property (nonatomic, retain) UITabBarController *tabBarController;
@property (nonatomic, retain) DFPeanutPushTokenAdapter *pushTokenAdapter;

// These are used to track the state of background fetch signals from the syncer and uploader
@property (nonatomic, assign) BOOL backgroundSyncHasFinished;
@property (nonatomic, assign) BOOL backgroundSyncAndUploaderHaveFinished;
@property (nonatomic, assign) BOOL backgroundSyncInProgress;
@property (nonatomic) NSUInteger backgroundSyncTotalBytes;
@property (nonatomic, retain) NSDate * firstRunSyncTimestamp;
@property (nonatomic, retain) NSTimer *backgroundSyncCancelUploadsTimer;
@property (nonatomic, retain) NSTimer *backgroundSyncReturnTimer;

@end

@implementation AppDelegate

const NSUInteger MinValidAccountId = 650;

// This is used to store the completion handler during our background syncs
void (^_completionHandler)(UIBackgroundFetchResult);

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self printSimulatorInfo];
  [self configureLogs];
  [self configureHockey];
  [self configureUI];
  
  if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
    [self application:application didReceiveRemoteNotification:
     launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]];
  }
  
  if (launchOptions[UIApplicationLaunchOptionsLocationKey]) {
    [[DFBackgroundLocationManager sharedManager] startUpdatingOnSignificantLocationChange];
  }
  
  [self configureBackgroundAppRefresh];
  
  return YES;
}

- (void)printSimulatorInfo
{
#if TARGET_IPHONE_SIMULATOR
  NSLog(@"Simulator build running from: %@", [ [NSBundle mainBundle] bundleURL] );
  NSLog(@"Simulator User Docs: %@", [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                            inDomains:NSUserDomainMask]
                                     lastObject]);
#endif
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
  /* 
   Object Mapping log levels
   To debug object mapping issues, use RKLogLevelTrace
   To debug object mapping latency, use RKLogLevelInfo
   */
  RKLogConfigureByName("RestKit/ObjectMapping", RKLogLevelError);
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

- (void)configureUI
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [self.window makeKeyAndVisible];
  
  if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
    // only create views etc if we're not being launched in the background
    [self createRootViewController];
  }
}

- (void)configureBackgroundAppRefresh
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(backgroundCameraRollSyncFinished)
                                               name:DFCameraRollSyncCompleteNotificationName
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(backgroundUploaderFinished)
                                               name:DFUploaderCompleteNotificationName
                                             object:nil];
  
  [[UIApplication sharedApplication]
   setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
}

- (BOOL)isAppSetupComplete
{
  return  ([[DFUser currentUser] userID]
           && ![[DFUser currentUser] userID] == 0
           && ![[DFDefaultsStore stateForPermission:DFPermissionPhotos]
                isEqual:DFPermissionStateNotRequested]);
}

- (void)showFirstTimeSetup
{
  [DFPhotoStore resetStore]; // make sure the photo store is clean
  DFNUXFlowViewController *setupViewController = [[DFNUXFlowViewController alloc] init];
  self.window.rootViewController = setupViewController;
}

/*
 This gets called as soon as the last of the first time setup steps area complete.
 Right now, that is after the location permission is done.  This is called directly from the
 controller.
 */
- (void)firstTimeSetupComplete
{
  [self showMainView];
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
  DFHomeViewController *homeViewController = [[DFHomeViewController alloc] init];
  DFNavigationController *navController = [[DFNavigationController alloc] initWithRootViewController:homeViewController];
  
  self.window.rootViewController = navController;
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
      // Tell the server that the app was woken up and register timestamp
      NSDate *now = [[NSDate alloc] init];
      DDLogVerbose(@"Setting last checkin time to %@", now);
      
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
       object:self];
      
      [[DFUserInfoManager sharedManager] setLastCheckinTimestamp:now];
      
      [[DFCameraRollSyncManager sharedManager] sync];
      [[DFCameraRollSyncManager sharedManager] deletedPhotoSync];
      [[DFContactSyncManager sharedManager] sync];
      [[DFUploadController sharedUploadController] uploadPhotos];
      [[DFSocketsManager sharedManager] initNetworkCommunication];
      [[DFImageDownloadManager sharedManager] fetchNewImages];
      [[DFImageDiskCache sharedStore] loadDownloadedImagesCache];
      [[DFBackgroundLocationManager sharedManager] startUpdatingOnSignificantLocationChange];
      // Clearing out our phone number to name cache incase the contact list changed
      [[DFContactDataManager sharedManager] refreshCacheWithCompletion:nil];
      [DFPushNotificationsManager refreshPushToken];
      [[DFUserInfoManager sharedManager] setLastNotifsOpenedTimestamp:[NSDate date]];
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
  [FBSettings setDefaultAppID:@"349028151970059"];
  [FBAppEvents activateApp];
  [self performForegroundOperations];
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


- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
  DDLogInfo(@"App handleOpenURL: %@", url);
  [DFAnalytics logURLOpenedAppWithURL:url otherParams:nil];
  
  return YES;
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
      
      if (self.backgroundSyncTotalBytes > 0) {
        DDLogInfo(@"Returning NewData result for background uploader since we uploaded %lul bytes", (unsigned long)self.backgroundSyncTotalBytes);
        if (_completionHandler) _completionHandler(UIBackgroundFetchResultNewData);
      } else {
        DDLogInfo(@"Returning NoData result for background uploader");
        if (_completionHandler) _completionHandler(UIBackgroundFetchResultNoData);
      }
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
  if (_completionHandler) _completionHandler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  [self application:application
performFetchWithCompletionHandler:completionHandler
       forceCheckin:NO];
}

/*
 * This is called every few minutes or so as a background process.
 * We have 30 seconds to return, so put in a timer to enforce that.
 * Normally throttled to kDFMaxBackgroundFetchTimeInterval unless force is YES
 */
- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
       forceCheckin:(BOOL)forceCheckin
{
  NSDate *startDate = [NSDate date];
  DDLogInfo(@"Strand background app refresh called at %@ forceCheckin:%d", startDate, forceCheckin);
  NSDate *lastBackgroundFetchStartDate = [DFDefaultsStore
                                          lastDateForAction:DFUserActionLastBackgroundReferesh];
 
  // this update call sometimes happens in very quick succession, particularly when
  // it's occurring as a result of a background location update. Throttle to once every 5m
  if (lastBackgroundFetchStartDate
      && [startDate timeIntervalSinceDate:lastBackgroundFetchStartDate] < kDFMaxBackgroundFetchTimeInterval
      && !forceCheckin) {
    DDLogInfo(@"time interval since last background fetch: %.02fs. Aborting.",
              [startDate timeIntervalSinceDate:lastBackgroundFetchStartDate]);
    if (completionHandler) completionHandler(UIBackgroundFetchResultNoData);
    return;
  } else {
    [DFDefaultsStore setLastDate:startDate forAction:DFUserActionLastBackgroundReferesh];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
  self.backgroundSyncTotalBytes = 0;

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
  
  // Have the uploader tell our local variable how many bytes it synced
  // This is done so we know if to return "NewData" or "NoData"
  [DFUploadController sharedUploadController].completionBlock = ^(DFUploadSessionStats *sessionStats) {
    self.backgroundSyncTotalBytes += sessionStats.numBytesUploaded;
  };
  [[DFCameraRollSyncManager sharedManager] sync];
  // Tell the server that the app was woken up and register timestamp
  NSDate *now = [[NSDate alloc] init];
  DDLogVerbose(@"Setting last checkin time to %@", now);
  [[DFUserInfoManager sharedManager] setLastCheckinTimestamp:now];
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
    
    [[DFCameraRollSyncManager sharedManager] cancelSyncOperations];
    [[DFUploadController sharedUploadController] cancelUploads:NO];
    [DFPhotoStore resetStore];
    [[DFContactsStore sharedStore] resetStore];
    [[DFPeanutFeedDataManager sharedManager] resetManager];
    
    // If more settings reset goes here, move to a DFSettings "reset" method
    [[DFSettings sharedSettings] setAutosaveToCameraRoll:NO];
    
    // clear user defaults
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    
    DDLogInfo(@"App reset complete.  Showing first time setup.");
    [self showFirstTimeSetup];
  });
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

+ (AppDelegate *)appDelegate
{
  return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

@end
