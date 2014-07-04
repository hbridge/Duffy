//
//  ModelController.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "SubviewsController.h"
#import "DFCameraViewController.h"
#import "DFGalleryWebViewController.h"
#import "DFGalleryViewController.h"
#import "DFPhotoNavigationControllerViewController.h"
#import "DFPhotoFeedController.h"

/*
 A controller object that manages a simple model -- a collection of month names.
 
 The controller serves as the data source for the page view controller; it therefore implements pageViewController:viewControllerBeforeViewController: and pageViewController:viewControllerAfterViewController:.
 It also implements a custom method, viewControllerAtIndex: which is useful in the implementation of the data source methods, and in the initial configuration of the application.
 
 There is no need to actually create view controllers for each page in advance -- indeed doing so incurs unnecessary overhead. Given the data model, these methods create, configure, and return a new view controller on demand.
 */


@interface SubviewsController ()

@property (readonly, strong, nonatomic) NSArray *subviewControllers;

@end

@implementation SubviewsController

- (instancetype)init {
  self = [super init];
  if (self) {
    _subviewControllers =
    @[
     [[UINavigationController alloc]
      initWithRootViewController:[[DFPhotoFeedController alloc] init]],
     [[DFCameraViewController alloc] init]
      ];
  }
  return self;
}

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index storyboard:(UIStoryboard *)storyboard {
  // Return the data view controller for the given index.
  if (index >= self.subviewControllers.count) return nil;
  return self.subviewControllers[index];
}

- (NSUInteger)indexOfViewController:(DataViewController *)viewController {
  return [self.subviewControllers indexOfObject:viewController];
}

#pragma mark - Page View Controller Data Source

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
  NSUInteger index = [self indexOfViewController:(DataViewController *)viewController];
  if ((index == 0) || (index == NSNotFound)) {
    return nil;
  }
  
  index--;
  return [self viewControllerAtIndex:index storyboard:viewController.storyboard];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
  NSUInteger index = [self indexOfViewController:(DataViewController *)viewController];
  if (index == NSNotFound) {
    return nil;
  }
  
  index++;
  if (index == [self.subviewControllers count]) {
    return nil;
  }
  return [self viewControllerAtIndex:index storyboard:viewController.storyboard];
}

@end
