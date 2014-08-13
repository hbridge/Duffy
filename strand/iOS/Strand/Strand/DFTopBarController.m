//
//  DFTopBarController.m
//  Strand
//
//  Created by Henry Bridge on 8/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFTopBarController.h"
#import "DFOverlayViewController.h"

@interface DFTopBarController ()

@property (nonatomic) CGFloat previousScrollViewYOffset;
@property (atomic) BOOL isViewTransitioning;

@end

CGFloat const StatusBarHeight = 20.0;
CGFloat const NavBarHeight = 44.0 + StatusBarHeight;
CGFloat const MinNavbarOriginY = -NavBarHeight + StatusBarHeight; // we want a background for the status bar
CGFloat const MaxNavbarOriginY = 0;

@implementation DFTopBarController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _navigationBar = [[DFNavigationBar alloc]
                    initWithFrame:CGRectMake(0,
                                             0,
                                             self.view.frame.size.width,
                                             NavBarHeight)];
  [self.view addSubview:self.navigationBar];
  self.navigationBar.items = @[self.navigationItem];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  self.isViewTransitioning = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  self.isViewTransitioning = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  self.isViewTransitioning = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  self.isViewTransitioning = NO;
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (![self shouldHandleScrollChange]) return;
  CGRect navbarFrame = self.navigationBar.frame;
  
  CGFloat scrollOffset = scrollView.contentOffset.y;
  CGFloat scrollDiff = scrollOffset - self.previousScrollViewYOffset;
  
  if (scrollOffset <= -scrollView.contentInset.top) {
    // we're at the top of the scrollview, show the nav bar
    navbarFrame.origin.y = 0;
  } else {
    // the user has scrolled, set the origin of the navbar based on how much the user just scrolled
    // but keeping it to within MinNavbarOriginY and MaxNavbarOriginY
    navbarFrame.origin.y = MIN(MaxNavbarOriginY, MAX(MinNavbarOriginY, navbarFrame.origin.y - scrollDiff));
  }
  
  [self setNavbarFrame:navbarFrame];

  // store the scrollOffset for calculations next time around
  self.previousScrollViewYOffset = scrollOffset;
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

- (BOOL)shouldHandleScrollChange
{
  if (self.isViewTransitioning || !self.view.window) return NO;

  return YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
  [self stoppedScrolling];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate
{
  if (!decelerate) {
    [self stoppedScrolling];
  }
}
- (void)stoppedScrolling
{
  if (![self shouldHandleScrollChange]) return;
  
  CGRect frame = self.navigationBar.frame;
  if (frame.origin.y < 0) {
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


@end
