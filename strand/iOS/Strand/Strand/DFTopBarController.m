//
//  DFTopBarController.m
//  Strand
//
//  Created by Henry Bridge on 8/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFTopBarController.h"
#import "DFOverlayViewController.h"
#import "DFStrandsViewController.h"

@interface DFTopBarController ()

@property (nonatomic, retain) UIView *contentView;

@end

CGFloat const StatusBarHeight = 20.0;
CGFloat const NavBarHeight = 44.0 + StatusBarHeight;
CGFloat const MinNavbarOriginY = -NavBarHeight + StatusBarHeight; // we want a background for the status bar
CGFloat const MaxNavbarOriginY = 0;

@implementation DFTopBarController

- (instancetype)initWithRootViewController:(UIViewController *)viewController
{
  self = [super init];
  if (self) {
    self.viewControllers = @[viewController];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _navigationBar = [[DFNavigationBar alloc]
                    initWithFrame:CGRectMake(0,
                                             0,
                                             self.view.frame.size.width,
                                             NavBarHeight)];
  _navigationBar.delegate = self;
  [self.view addSubview:self.navigationBar];
  
  if (self.viewControllers.lastObject) {
    UIViewController *vc = self.viewControllers.lastObject;
    [self setContentView:vc.view];
    self.navigationBar.items = @[vc.navigationItem];
  }
}

- (void)setViewControllers:(NSArray *)viewControllers
{
  _viewControllers = viewControllers;
  NSMutableArray *navigationItems = [NSMutableArray new];
  for (DFStrandsViewController *vc in viewControllers) {
    [self addChildViewController:vc];
    [navigationItems  addObject:vc.navigationItem];
    vc.topBarController = self;
  }
  
  self.navigationBar.items = navigationItems;
}

- (void)pushViewController:(DFStrandsViewController *)viewController animated:(BOOL)animated
{
  if (!self.viewControllers) self.viewControllers = @[];
  self.viewControllers = [self.viewControllers arrayByAddingObject:viewController];
  self.contentView = viewController.view;
  self.navigationBar.items = [self.navigationBar.items arrayByAddingObject:viewController.navigationItem];
  //[self.navigationBar pushNavigationItem:viewController.navigationItem animated:animated];
  //self.navigationBar.topItem.titleView = viewController.navigationItem.titleView;
  viewController.topBarController = self;
  DDLogInfo(@"pushViewController backItem:%@ leftItems:%@ titleView:%@ rightItems:%@",
            viewController.navigationItem.backBarButtonItem,
            viewController.navigationItem.leftBarButtonItems,
            viewController.navigationItem.titleView,
            viewController.navigationItem.rightBarButtonItems);
}

- (void)popViewControllerAnimated:(BOOL)animated popNavBar:(BOOL)popNavBar
{
  if (self.viewControllers.count == 1) {
    [NSException raise:@"Cannot pop root view controller"
                format:@"%@ trying to pop root view controller.", [self.class description]];
  }
  
  self.viewControllers = [self.viewControllers
                          subarrayWithRange:(NSRange){0, self.viewControllers.count - 1}];
  UIViewController *newTopViewController = self.viewControllers.lastObject;
  self.contentView = newTopViewController.view;
}

- (void)popViewControllerAnimated:(BOOL)animated
{
  [self popViewControllerAnimated:animated popNavBar:YES];
}

- (void)setContentView:(UIView *)newContentView
{
  CGRect frame = self.view.frame;
  frame.origin.y = self.navigationBar.frame.origin.y + self.navigationBar.frame.size.height;
  frame.size.height = self.view.frame.size.height - frame.origin.y;
  newContentView.frame = frame;
  
  [self.contentView removeFromSuperview];
  [self.view addSubview:newContentView];
  _contentView = newContentView;
}

#pragma mark - UIScrollViewDelegate

- (void)mainScrollViewScrolledToTop:(BOOL)isTop dy:(CGFloat)dy
{
  CGRect navbarFrame = self.navigationBar.frame;
  
  if (isTop) {
    // we're at the top of the scrollview, show the nav bar
    navbarFrame.origin.y = 0;
  } else {
    // the user has scrolled, set the origin of the navbar based on how much the user just scrolled
    // but keeping it to within MinNavbarOriginY and MaxNavbarOriginY
    navbarFrame.origin.y = MIN(MaxNavbarOriginY, MAX(MinNavbarOriginY, navbarFrame.origin.y - dy));
  }
  
  [self setNavbarFrame:navbarFrame];
}

/* 
 Sets the navbar frame, handling necessary side effects like updating the contentView's frame
 and updating the alpha of the navbar items accordingly.
 */
- (void)setNavbarFrame:(CGRect)newFrame
{
  // set the new frame, update the content view frame, calc and set alpha for buttons
  [self.navigationBar setFrame:newFrame];
  [self updateContentViewFrame];
  CGFloat framePercentageHidden = newFrame.origin.y / MinNavbarOriginY;
  [self.navigationBar setItemAlpha:(1 - framePercentageHidden)];
}

- (void)updateContentViewFrame
{
  CGRect contentViewFrame = self.view.frame;
  contentViewFrame.origin.y = self.navigationBar.frame.origin.y + self.navigationBar.frame.size.height;
  contentViewFrame.size.height = self.contentView.window.frame.size.height - contentViewFrame.origin.y;
  self.contentView.frame = contentViewFrame;
}

- (void)mainScrollViewStoppedScrolling
{
  if (self.navigationBar.frame.origin.y < 0) {
    [self animateNavBarTo:MinNavbarOriginY];
  }
}


- (void)animateNavBarTo:(CGFloat)y
{
  [UIView animateWithDuration:0.2 animations:^{
    CGRect frame = self.navigationBar.frame;
    frame.origin.y = y;
    [self setNavbarFrame:frame];
  }];
}

- (void)showNavBar
{
  if (self.navigationBar.frame.origin.y < 0) {
    [self animateNavBarTo:0];
  }
}

- (void)navigationBar:(UINavigationBar *)navigationBar didPopItem:(UINavigationItem *)item
{
  [self popViewControllerAnimated:YES popNavBar:NO];
}

- (void)navigationBar:(UINavigationBar *)navigationBar didPushItem:(UINavigationItem *)item
{
  
}


@end
