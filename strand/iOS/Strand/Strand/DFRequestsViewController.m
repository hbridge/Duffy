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
  DFRequestViewController *referenceRequestVC = (DFRequestViewController *)viewController;
  NSInteger currentIndex = [self.inviteFeedObjects indexOfObject:referenceRequestVC.inviteFeedObject];
  NSInteger beforeIndex = currentIndex - 1;
  if (beforeIndex < 0) beforeIndex = self.inviteFeedObjects.count - 1; // wrap around
  return [self viewControllerForIndex:beforeIndex];
 }

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.inviteFeedObjects.count < 2) return nil;
  DFRequestViewController *referenceRequestVC = (DFRequestViewController *)viewController;
  NSInteger currentIndex = [self.inviteFeedObjects indexOfObject:referenceRequestVC.inviteFeedObject];
  NSInteger afterIndex = currentIndex + 1;
  if (afterIndex >= self.inviteFeedObjects.count) afterIndex = 0; // wrap around
  return [self viewControllerForIndex:afterIndex];
}



@end
