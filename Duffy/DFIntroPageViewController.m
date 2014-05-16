//
//  DFIntroPageViewController.m
//  Duffy
//
//  Created by Henry Bridge on 5/15/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFIntroPageViewController.h"
#import "DFIntroContentViewController.h"
#import "DFAppDelegate.h"

@interface DFIntroPageViewController ()

@property (nonatomic, retain) NSMutableArray *viewControllersArr;
@property (nonatomic, retain) UIPageViewController *pageViewController;

@end

@implementation DFIntroPageViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self setPagingStyle];
  
  // instantiate the page view controller
  self.pageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PageViewController"];
  self.pageViewController.dataSource = self;
  
  // create the sub pages and set the page view to the first view controller
  self.viewControllersArr = [[NSMutableArray alloc] init];
  for (int i = 0; i < 3; i++) {
    DFIntroContentViewController *cvc =
    [self.storyboard instantiateViewControllerWithIdentifier:@"DFIntroContentViewController"];
    cvc.pageIndex = i;
    cvc.pageViewController = self;
    [self.viewControllersArr addObject:cvc];
  }
  
  [self.pageViewController setViewControllers:@[self.viewControllersArr[0]]
                                    direction:UIPageViewControllerNavigationDirectionForward
                                     animated:NO
                                   completion:nil];
  
  // add the page view controller to view
  [self addChildViewController:self.pageViewController];
  [self.view addSubview:self.pageViewController.view];
  [self.pageViewController didMoveToParentViewController:self];
}

- (void)setPagingStyle
{
  UIPageControl *pageControl = [UIPageControl appearance];
  pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
  pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
  pageControl.backgroundColor = [UIColor whiteColor];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}


- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  NSUInteger currentIndex = [self.viewControllersArr indexOfObject:viewController];
  if (self.viewControllersArr.count >  currentIndex + 1) {
    return self.viewControllersArr[currentIndex + 1];
  }
  
  return nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  NSUInteger currentIndex = [self.viewControllersArr indexOfObject:viewController];
  if (currentIndex > 0) {
    return self.viewControllersArr[currentIndex - 1];
  }
  
  return nil;
}

- (DFIntroContentViewController *)viewControllerAtIndex:(NSUInteger)index
{
  return self.viewControllersArr[index];
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
{
  return [self.viewControllersArr indexOfObject:self.pageViewController.viewControllers.firstObject];
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
{
  return [self.viewControllersArr count];
}


- (void)showNextStep:(UIViewController *)currentViewController
{
  UIViewController *nextController = [self pageViewController:self.pageViewController
                            viewControllerAfterViewController:currentViewController];
  if (nextController) {
    [self.pageViewController setViewControllers:@[nextController]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:YES
                                     completion:nil];
  } else { // this is the last step, show logged in tabs instead
    DFAppDelegate *appDelegate = (DFAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate showLoggedInUserTabs];
  }
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
