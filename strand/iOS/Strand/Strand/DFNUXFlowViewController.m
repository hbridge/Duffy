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
    [[DFCreateAccountViewController alloc] init],
    [[DFSMSAuthViewController alloc] init],
    [[DFPhotosPermissionViewController alloc] init],
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
