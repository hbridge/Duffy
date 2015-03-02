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
#import "DFFriendsRequiredNUXViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFDefaultsStore.h"
#import "DFAppInfo.h"


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
  DFAddFriendsNUXViewController *addFriends = [DFAddFriendsNUXViewController new];
  
  self.allNuxViewControllers =
  @[
    welcome,
    createAccount,
    smsAuth,
    photosPermission,
    locationPermission,
    addFriends
    ];
  
  // figure out if we can resume setup from an earlier run
  BOOL resumeSetup = [[DFAppInfo buildNumber] isEqual:[DFDefaultsStore setupIncompleteBuildNum]];
  if (resumeSetup) {
    NSNumber *stepCompleted = [DFDefaultsStore setupCompletedStepIndex];
    DDLogInfo(@"%@ resuming setup at step: %@", self.class, stepCompleted);
    if (stepCompleted.integerValue >= 2) { // if we've passed auth, pick up from where we were
      NSUInteger startingIndex = stepCompleted.integerValue + 1;
      self.allNuxViewControllers = [self.allNuxViewControllers
                                    subarrayWithRange:(NSRange){startingIndex,
                                      self.allNuxViewControllers.count - startingIndex}];
    }
  } else {
    [DFUser setCurrentUser:nil];
    DDLogInfo(@"%@ starting setup from beginning", self.class);
  }
  
  [DFDefaultsStore setSetupStartedWithBuildNumber:[DFAppInfo buildNumber]];
  
  self.backEnabledViews = @[
                            smsAuth
                            ];
  
  [self gotoNextStep];
}

- (void)gotoNextStep
{
  DFNUXViewController *nextNuxController;
  if (!self.currentViewController) {
    nextNuxController = self.allNuxViewControllers.firstObject;
  } else {
    nextNuxController = [self.allNuxViewControllers objectAfterObject:self.currentViewController wrap:NO];
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
  nuxController.delegate = self;
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
  
  NSNumber *completedStepIndex =@([self.allNuxViewControllers indexOfObject:nuxController]);
  DDLogInfo(@"%@ marking step %@ completed.", self.class, completedStepIndex);
  [DFDefaultsStore setSetupCompletedStep:completedStepIndex];
  
  if (nuxController == self.currentViewController) {
    [self gotoNextStep];
  } else {
    DDLogWarn(@"%@ warning: %@ called completed when not currentVC.", self.class, [nuxController class]);
  }
}

- (void)flowComplete
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DDLogInfo(@"%@ setup complete", self.class);
    [DFDefaultsStore setSetupCompletedForBuildNumber:[DFAppInfo buildNumber]];
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
