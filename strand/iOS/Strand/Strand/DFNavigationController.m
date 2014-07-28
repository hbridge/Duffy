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
@property (nonatomic) BOOL doesAnimateInStatusBar;

@end

@implementation DFNavigationController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
  return [self initWithRootViewController:rootViewController animateInStatusBar:NO];
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
                        animateInStatusBar:(BOOL)animateInStatusBar
{
  if (animateInStatusBar) {
    self = [super initWithNavigationBarClass:[DFNavigationBar class] toolbarClass:[UIToolbar class]];
  } else {
    self = [super init];
  }
  if (self) {
    _doesAnimateInStatusBar = animateInStatusBar;
    self.viewControllers = @[rootViewController];
  }
  
  return self;

}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.navigationBar.barTintColor = [DFStrandConstants defaultBackgroundColor];
  self.navigationBar.tintColor = [DFStrandConstants defaultBarForegroundColor];
  self.navigationBar.titleTextAttributes = @{
                                             NSForegroundColorAttributeName:
                                               [DFStrandConstants defaultBarForegroundColor]
                                             };
  self.navigationBar.translucent = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
}

- (void)animateInStatusBar
{
  if (!self.overlayWindow) {
    self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.overlayWindow setWindowLevel:UIWindowLevelStatusBar];
    [self.overlayWindow setUserInteractionEnabled:NO];
        
    self.overlayVC = [[DFOverlayViewController alloc] init];
    [self.overlayWindow setRootViewController:self.overlayVC];
  }
  
  [self.overlayWindow setHidden:NO];
  [self.overlayWindow makeKeyWindow];
  
  [self.overlayVC animateIn:^(BOOL finished) {
    self.overlayWindow.hidden = YES;
  }];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

-(UIStatusBarStyle)preferredStatusBarStyle{
  return UIStatusBarStyleLightContent;
}



@end
