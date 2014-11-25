//
//  DFRequestsViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFRequestsViewController.h"
#import "DFRequestViewController.h"
#import "DFPeanutFeedObject.h"

@interface DFRequestsViewController ()

@property (nonatomic, retain) UIPageControl *pageControl;

@end

@implementation DFRequestsViewController

@synthesize inviteFeedObjects = _inviteFeedObjects;
@synthesize height = _height;

- (instancetype)init
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                options:nil];
  if (self) {
    self.delegate = self;
    self.dataSource = self;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.height = self.height;
  [self configurePageControl];
}

- (void)configurePageControl
{
  if (!self.pageControl) {
    self.pageControl = [[UIPageControl alloc] init];
    [self.view addSubview:self.pageControl];
    self.pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[pageControl]-(5)-|"
                               options:0//NSLayoutFormatDirectionRightToLeft
                              metrics:nil
                              views:@{@"pageControl" : self.pageControl}]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.pageControl
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1.0
                                                           constant:0]];
    [self.pageControl addConstraint:[NSLayoutConstraint constraintWithItem:self.pageControl
                                                          attribute:NSLayoutAttributeHeight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:nil
                                                          attribute:NSLayoutAttributeHeight
                                                         multiplier:1.0
                                                           constant:10]];
    self.pageControl.currentPage = 0;
  }
  self.pageControl.numberOfPages = self.inviteFeedObjects.count;
  UIViewController *currentController = self.viewControllers.firstObject;
  self.pageControl.currentPage = [self indexOfViewController:currentController];
  [self.pageControl sizeToFit];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  if (self.viewControllers.count == 0 && self.inviteFeedObjects.count > 0) {
    DFRequestViewController *rvc = [self viewControllerForIndex:0];
    [self setViewControllers:@[rvc]
                   direction:UIPageViewControllerNavigationDirectionForward
                    animated:NO
                  completion:nil];
    [self configurePageControl];
  }
}

- (void)setHeight:(CGFloat)height
{
  _height = height;
  CGRect frame = self.view.frame;
  frame.size.height = self.height;
  self.view.frame = frame;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setInviteFeedObjects:(NSArray *)inviteFeedObjects
{
  _inviteFeedObjects = inviteFeedObjects;
}

- (NSUInteger)indexOfViewController:(UIViewController *)viewController
{
  DFRequestViewController *referenceRequestVC = (DFRequestViewController *)viewController;
  NSInteger currentIndex = [self.inviteFeedObjects indexOfObject:referenceRequestVC.inviteFeedObject];
  return currentIndex;
}

- (DFRequestViewController *)viewControllerForIndex:(NSInteger)index
{
  DFPeanutFeedObject *invite = self.inviteFeedObjects[index];
  DFRequestViewController *rvc = [[DFRequestViewController alloc] init];
  rvc.inviteFeedObject = invite;
  rvc.frame = self.view.bounds;
  DFRequestsViewController __weak *weakSelf = self;
  rvc.selectButtonHandler = ^{
    [weakSelf.actionDelegate requestsViewController:weakSelf inviteSelected:invite];
  };
  return rvc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  if (self.inviteFeedObjects.count < 2) return nil;
  
  NSUInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger beforeIndex = currentIndex - 1;
  if (beforeIndex < 0) beforeIndex = self.inviteFeedObjects.count - 1; // wrap around
  return [self viewControllerForIndex:beforeIndex];
 }

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.inviteFeedObjects.count < 2) return nil;
  NSInteger currentIndex = [self indexOfViewController:viewController];
  NSInteger afterIndex = currentIndex + 1;
  if (afterIndex >= self.inviteFeedObjects.count) afterIndex = 0; // wrap around
  return [self viewControllerForIndex:afterIndex];
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  UIViewController *newVC = pageViewController.viewControllers.firstObject;
  NSUInteger newIndex = [self indexOfViewController:newVC];
  self.pageControl.currentPage = newIndex;
}



@end
