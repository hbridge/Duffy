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

@interface DFNUXFlowViewController ()

@property (nonatomic, retain) DFNUXViewController *currentViewController;
@property (nonatomic, retain) NSArray *allNuxViewControllers;

@end

@implementation DFNUXFlowViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.allUserInfo = [NSMutableDictionary new];
  self.allNuxViewControllers =
  @[
    [DFCreateAccountViewController new],
    [DFSMSAuthViewController new],
    [DFPhotosPermissionViewController new],
    [DFFindFriendsNUXViewController new],
    [DFAddFriendsNUXViewController new],
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
  
  self.currentViewController = nextNuxController;
  nextNuxController.inputUserInfo = self.allUserInfo;
  
  if (nextNuxController) {
    [self setViewControllers:@[nextNuxController] animated:YES];
  } else {
    [self flowComplete];
  }
}

- (void)NUXController:(DFNUXViewController *)nuxController completedWithUserInfo:(NSDictionary *)userInfo
{
  [self.allUserInfo addEntriesFromDictionary:userInfo];
  [self gotoNextStep];
}

- (void)flowComplete
{
  dispatch_async(dispatch_get_main_queue(), ^{
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate firstTimeSetupComplete];
  });
}

@end
