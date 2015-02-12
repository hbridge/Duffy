//
//  DFNUXFlowViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFNUXFlowViewController.h"
#import "DFCreateAccountViewController.h"
#import "DFSMSAuthViewController.h"
#import "DFPhotosPermissionViewController.h"
#import "AppDelegate.h"
#import "DFFindFriendsNUXViewController.h"
#import "DFAddFriendsNUXViewController.h"
#import "DFAlertController.h"
#import "DFContactSyncManager.h"
#import "DFSocketsManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFImageDownloadManager.h"
#import "DFWelcomeNUXViewController.h"
#import "DFLocationPermissionViewController.h"


@interface DFNUXFlowViewController ()

@property (nonatomic, readonly, retain) UIViewController *currentViewController;
@property (nonatomic, retain) NSArray *allNuxViewControllers;
@property (nonatomic, retain) NSArray *backEnabledViews;
@property (nonatomic) BOOL uidTasksRun;

@end

@implementation DFNUXFlowViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  

  self.allUserInfo = [NSMutableDictionary new];
  
  DFWelcomeNUXViewController *welcome = [DFWelcomeNUXViewController new];
  DFCreateAccountViewController *createAccount = [DFCreateAccountViewController new];
  DFSMSAuthViewController *smsAuth = [DFSMSAuthViewController new];
  DFPhotosPermissionViewController *photosPermission = [DFPhotosPermissionViewController new];
  DFLocationPermissionViewController *locationPermission = [DFLocationPermissionViewController new];
  DFFindFriendsNUXViewController *findFriends = [DFFindFriendsNUXViewController new];
  DFAddFriendsNUXViewController *addFriends = [DFAddFriendsNUXViewController new];
  
  self.allNuxViewControllers =
  @[
    welcome,
    createAccount,
    smsAuth,
    photosPermission,
    locationPermission,
    findFriends,
    addFriends
    ];
  
  self.backEnabledViews = @[
                            smsAuth
                            ];
  
  for (DFNUXViewController *vc in self.allNuxViewControllers) {
    vc.delegate = self;
  }
  
  [self gotoNextStep];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)gotoNextStep
{
  DFNUXViewController *nextNuxController;
  if (!self.currentViewController) {
    nextNuxController = self.allNuxViewControllers.firstObject;
  } else {
    nextNuxController = [self.allNuxViewControllers objectAfterObject:self.currentViewController
                                                                 wrap:NO];
  }
  
  
  nextNuxController.inputUserInfo = self.allUserInfo;
  
  if (nextNuxController) {
    [self setActiveNUXController:nextNuxController];
  } else {
    [self flowComplete];
  }
}

- (void)setActiveNUXController:(DFNUXViewController *)nuxController
{
  if ([self.backEnabledViews containsObject:nuxController]) {
    [self pushViewController:nuxController animated:YES];
  } else {
    [self setViewControllers:@[nuxController] animated:YES];
  }
}

- (void)NUXController:(DFNUXViewController *)nuxController completedWithUserInfo:(NSDictionary *)userInfo
{
  [self.allUserInfo addEntriesFromDictionary:userInfo];
  if ([[DFUser currentUser] userID]) {
    [self userIDStepComplete];
  }
  
  if (nuxController == self.currentViewController) {
    [self gotoNextStep];
  } else {
    DDLogWarn(@"%@ warning: %@ called completed when not currentVC.", self.class, [nuxController class]);
  }
}

- (void)flowComplete
{
  dispatch_async(dispatch_get_main_queue(), ^{
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate firstTimeSetupComplete];
  });
}

- (UIViewController *)currentViewController
{
  return self.viewControllers.lastObject;
}

- (void)userIDStepComplete
{
  if (!self.uidTasksRun) {
    DDLogInfo(@"%@ userID detected. Performing UID tasks.", self.class);
    [[DFSocketsManager sharedManager] initNetworkCommunication];
    [[DFPeanutFeedDataManager sharedManager] refreshFeedFromServer:DFInboxFeed completion:nil];
    [[DFImageDownloadManager sharedManager] fetchNewImages];
    
    self.uidTasksRun = YES;
  }
}


@end
