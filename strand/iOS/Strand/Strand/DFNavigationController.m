//
//  DFNavigationController.m
//  Strand
//
//  Created by Henry Bridge on 7/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNavigationController.h"
#import "DFStrandConstants.h"
#import "DFOverlayViewController.h"
#import "DFNavigationBar.h"

@interface DFNavigationController ()

@property (nonatomic, retain) UIWindow *overlayWindow;
@property (nonatomic, retain) DFOverlayViewController *overlayVC;

@end

@implementation DFNavigationController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
  self = [super initWithNavigationBarClass:[DFNavigationBar class] toolbarClass:[UIToolbar class]];
  if (self) {
    self.viewControllers = @[rootViewController];
  }
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
}

-(UIStatusBarStyle)preferredStatusBarStyle{
  return UIStatusBarStyleLightContent;
}



@end
