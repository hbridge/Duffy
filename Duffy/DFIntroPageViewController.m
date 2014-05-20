//
//  DFIntroPageViewController.m
//  Duffy
//
//  Created by Henry Bridge on 5/15/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFIntroPageViewController.h"
#import "DFAppDelegate.h"

@interface DFIntroPageViewController ()

@property (nonatomic, retain) UIPageViewController *pageViewController;

@end

@implementation DFIntroPageViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self setPagingStyle];
  
  // instantiate the page view controller
  self.pageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PageViewController"];
  [self showNextContentViewController:DFIntroContentWelcome];
  
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


- (void)showNextContentViewController:(DFIntroContentType)contentType
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DFIntroContentViewController *icvc =
    [self.storyboard instantiateViewControllerWithIdentifier:@"DFIntroContentViewController"];
    icvc.introContent = contentType;
    icvc.pageViewController = self;
    [self.pageViewController setViewControllers:@[icvc]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:YES
                                     completion:nil];
  });
}

- (void)dismissIntro
{
  dispatch_async(dispatch_get_main_queue(), ^{
    DFAppDelegate *appDelegate = (DFAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate showLoggedInUserTabs];
  });
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
