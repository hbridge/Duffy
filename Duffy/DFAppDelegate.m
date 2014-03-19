//
//  DFAppDelegate.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAppDelegate.h"
#import "DFPhotoStore.h"
#import "DFCameraRollViewController.h"
#import "DFSettingsViewController.h"
#import "DFSearchViewController.h"
#import "DFCameraRollSyncController.h"


@interface DFAppDelegate()

@property (nonatomic, retain) DFCameraRollSyncController *cameraRollSyncController;

@end

@implementation DFAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Camera roll tab
    DFCameraRollViewController *cameraRollController = [[DFCameraRollViewController alloc] init];
    UINavigationController *cameraRollNav = [[UINavigationController alloc] initWithRootViewController:cameraRollController];
    
    DFSearchViewController *searchViewController = [[DFSearchViewController alloc] init];
    UINavigationController *searchViewNav = [[UINavigationController alloc] initWithRootViewController:searchViewController];
    
    
    DFSettingsViewController *settingsViewController = [[DFSettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    
    UITabBarController *tabController = [[UITabBarController alloc] init];
    [tabController setViewControllers:[NSArray arrayWithObjects:
                                       cameraRollNav,
                                       searchViewNav,
                                       settingsNav,
                                       nil]];
    
    [[self window] setRootViewController:tabController];
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
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
    NSLog(@"applicationDidBecomeActive");
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
    //[[DFPhotoStore sharedStore] emptyImageCache];
}


@end
