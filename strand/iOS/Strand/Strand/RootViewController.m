//
//  RootViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "RootViewController.h"
#import "DFNavigationController.h"
#import "DFCameraViewController.h"
#import "DFFeedViewController.h"
#import "DFOverlayViewController.h"
#import "DFTopBarController.h"
#import "DFGalleryViewController.h"

@interface RootViewController ()
            
@property (readonly, strong, nonatomic) NSArray *subviewControllers;

@property (nonatomic, retain) UIWindow *overlayWindow;
@property (nonatomic, retain) DFOverlayViewController *overlayVC;

@end

@implementation RootViewController

static RootViewController *mainRootViewController;
+ (RootViewController *)rootViewController
{
  return mainRootViewController;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    if (mainRootViewController) {
      DDLogWarn(@"Creating second mainRootViewController.  mainRootViewController.view.window: %@", mainRootViewController.view.window);
    }
    
    mainRootViewController = self;
    self.hideStatusBar = YES;
    _cameraViewController = [[DFCameraViewController alloc] init];
    _photoFeedController = [[DFFeedViewController alloc] init];
    _strandsNavController = [[DFTopBarController alloc]
                             initWithRootViewController:[[DFGalleryViewController alloc] init]];
    //    [_strandsNavController pushViewController:_photoFeedController animated:NO];
    _subviewControllers =
    @[
      _strandsNavController,
      _cameraViewController,
      ];

  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  // Configure the page view controller and add it as a child view controller.
  self.pageViewController = [[UIPageViewController alloc]
                             initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                             navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                             options:nil];
  self.pageViewController.delegate = self;
  self.pageViewController.view.backgroundColor = [UIColor blackColor];

  UIViewController *startingViewController = [self viewControllerAtIndex:1];
  NSArray *viewControllers = @[startingViewController];
  [self.pageViewController setViewControllers:viewControllers
                                    direction:UIPageViewControllerNavigationDirectionForward
                                     animated:NO
                                   completion:nil];

  self.pageViewController.dataSource = self;

  [self addChildViewController:self.pageViewController];
  [self.view addSubview:self.pageViewController.view];

  // Set the page view controller's bounds using an inset rect so that self's view is visible around the edges of the pages.
  CGRect pageViewRect = self.view.bounds;
  self.pageViewController.view.frame = pageViewRect;

  [self.pageViewController didMoveToParentViewController:self];

  // Add the page view controller's gesture recognizers to the book view controller's view so that the gestures are started more easily.
  self.view.gestureRecognizers = self.pageViewController.gestureRecognizers;
  
  [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

-(UIStatusBarStyle)preferredStatusBarStyle{
  return UIStatusBarStyleLightContent;
}

- (void)showGallery
{
  UIViewController *galleryViewController = [self viewControllerAtIndex:0];
  NSArray *viewControllers = @[galleryViewController];
  [self.pageViewController setViewControllers:viewControllers
                                    direction:UIPageViewControllerNavigationDirectionReverse
                                     animated:YES
                                   completion:nil];
  self.hideStatusBar = NO;
}

- (void)showCamera
{
  UIViewController *galleryViewController = [self viewControllerAtIndex:1];
  NSArray *viewControllers = @[galleryViewController];
  [self.pageViewController setViewControllers:viewControllers
                                    direction:UIPageViewControllerNavigationDirectionForward
                                     animated:YES
                                   completion:nil];
  self.hideStatusBar = YES;
}

- (void)showPhotoWithID:(DFPhotoIDType)photoID
{
  [self showGallery];
//  if ([self.photoFeedController respondsToSelector:@selector(jumpToPhoto:)]){
//    [self.photoFeedController jumpToPhoto:photoID];
//  }
}

#pragma mark - Page View Controller Data Source

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {
  // Return the data view controller for the given index.
  if (index >= self.subviewControllers.count) return nil;
  return self.subviewControllers[index];
}

- (NSUInteger)indexOfViewController:(UIViewController *)viewController {
  return [self.subviewControllers indexOfObject:viewController];
}


- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  NSUInteger index = [self indexOfViewController:viewController];
  if ((index == 0) || (index == NSNotFound)) {
    return nil;
  }
  
  index--;
  return [self viewControllerAtIndex:index];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  NSUInteger index = [self indexOfViewController:viewController];
  if (index == NSNotFound) {
    return nil;
  }
  
  index++;
  if (index == [self.subviewControllers count]) {
    return nil;
  }
  return [self viewControllerAtIndex:index];
}


#pragma mark - UIPageViewController delegate methods

- (UIPageViewControllerSpineLocation)pageViewController:(UIPageViewController *)pageViewController
                   spineLocationForInterfaceOrientation:(UIInterfaceOrientation)orientation {
  // Set the spine position to "min" and the page view controller's view controllers array to contain just one view controller. Setting the spine position to 'UIPageViewControllerSpineLocationMid' in landscape orientation sets the doubleSided property to YES, so set it to NO here.
  UIViewController *currentViewController = self.pageViewController.viewControllers[0];
  NSArray *viewControllers = @[currentViewController];
  [self.pageViewController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];

  self.pageViewController.doubleSided = NO;
  return UIPageViewControllerSpineLocationMin;
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  if (self.pageViewController.viewControllers.firstObject == _strandsNavController && finished) {
    self.hideStatusBar = NO;
  } else {
    self.hideStatusBar = YES;
  }
}

- (void)pageViewController:(UIPageViewController *)pageViewController
willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
  self.hideStatusBar = YES;
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


#pragma mark - Other Helpers

- (void)setHideStatusBar:(BOOL)hideStatusBar
{
  if (_hideStatusBar == hideStatusBar) return;
  _hideStatusBar = hideStatusBar;
  [self setNeedsStatusBarAppearanceUpdate];
  if (!hideStatusBar) {
    [self animateInStatusBar];
  }
}

- (BOOL)prefersStatusBarHidden
{
  return self.hideStatusBar;
}

- (void)setSwipingEnabled:(BOOL)isSwipingEnabled
{
  for (UIScrollView *view in self.pageViewController.view.subviews) {
    if ([view isKindOfClass:[UIScrollView class]]) {
      view.scrollEnabled = isSwipingEnabled;
    }
  }
}

@end
