//
//  DFAppDelegate.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAppDelegate.h"
#import "Flurry/Flurry.h"
#import "DFPhotoStore.h"
#import "DFCameraRollViewController.h"
#import "DFSettingsViewController.h"
#import "DFSearchViewController.h"
#import "DFCameraRollSyncController.h"
#import "DFPhotoNavigationControllerViewController.h"
#import "DFPhotoImageCache.h"
#import "DFFirstTimeSetupViewController.h"
#import "DFUser.h"
#import <HockeySDK/HockeySDK.h>




@interface DFAppDelegate()

@property (nonatomic, retain) DFCameraRollSyncController *cameraRollSyncController;

@end

@implementation DFAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"7e0628b85696cfd8bd471f9906fbc79f"];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
    
    [Flurry setCrashReportingEnabled:NO];
#ifdef DEBUG
    [Flurry startSession:@"YFWFVHZXVX8ZCWX643B9"];
    //[Flurry setLogLevel:FlurryLogLevelDebug];
#else
    [Flurry startSession:@"MMJXFR6J7J5Y3YB9MK6N"];
#endif
    
    if (![[DFUser currentUser] userID] || [[[DFUser currentUser] userID] isEqualToString:@""]) {
        [self showFirstTimeSetup];
    } else {
        [self showLoggedInUserTabs];
    }
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)showFirstTimeSetup
{
    DFFirstTimeSetupViewController *firstTimeSetup = [[DFFirstTimeSetupViewController alloc] init];
    [[self window] setRootViewController:firstTimeSetup];
}


- (void)showLoggedInUserTabs
{
    // Set the unique userID for logging
    [Flurry setUserID:[[DFUser currentUser] userID]];
    
    // Camera roll tab
    DFCameraRollViewController *cameraRollController = [[DFCameraRollViewController alloc] init];
    UINavigationController *cameraRollNav = [[DFPhotoNavigationControllerViewController alloc] initWithRootViewController:cameraRollController];
    
    DFSearchViewController *searchViewController = [[DFSearchViewController alloc] init];
    UINavigationController *searchViewNav = [[UINavigationController alloc] initWithRootViewController:searchViewController];
    
    
    DFSettingsViewController *settingsViewController = [[DFSettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    
    UITabBarController *tabController = [[UITabBarController alloc] init];
    [tabController setViewControllers:[NSArray arrayWithObjects:
                                       searchViewNav,
                                       cameraRollNav,
                                       settingsNav,
                                       nil]];
    
    [[self window] setRootViewController:tabController];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [[DFPhotoStore sharedStore] saveContext];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if (self.cameraRollSyncController == nil) {
        self.cameraRollSyncController = [[DFCameraRollSyncController alloc] init];
    }
    
    NSSet *dbKnownURLs = [[[DFPhotoStore sharedStore] cameraRoll] photoURLSet];
    [self.cameraRollSyncController asyncSyncToCameraRollWithCurrentKnownPhotoURLs:dbKnownURLs];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [[DFPhotoStore sharedStore] saveContext];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    NSLog(@"memory warning.  emptying cache.");
    [[DFPhotoImageCache sharedCache] emptyCache];
}


@end
