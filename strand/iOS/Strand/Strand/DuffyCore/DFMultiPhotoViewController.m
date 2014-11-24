//
//  DFMultiPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFMultiPhotoViewController.h"
#import "DFAnalytics.h"
#import "DFPhotoViewController.h"

@interface DFMultiPhotoViewController ()

@property (nonatomic) NSUInteger currentPhotoIndex;
@property (nonatomic, retain) NSArray *photos;

@property (nonatomic) BOOL hideStatusBar;

@end

@implementation DFMultiPhotoViewController


- (id)init
{
  self = [super init];
  if (self) {
    self.hidesBottomBarWhenPushed = YES;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self setupPVC];
  [self setTheatreModeEnabled:NO];
}

- (void)setupPVC
{
  _pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                        navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                      options:@{UIPageViewControllerOptionInterPageSpacingKey:[NSNumber numberWithFloat:40.0]}];
  _pageViewController.delegate = self;
  _pageViewController.dataSource = self;
  _pageViewController.automaticallyAdjustsScrollViewInsets = NO;
  
  _pageViewController.navigationItem.title = @"Preview";
  _pageViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                                            initWithImage:[UIImage imageNamed:@"Assets/Icons/BackNavButton"]
                                                            style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(backPressed:)];
  
  [self showPhoto:self.activePhoto];
  [self pushViewController:_pageViewController animated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
}

- (void)setNavigationTitle:(NSString *)navigationTitle
{
  self.pageViewController.navigationItem.title = navigationTitle;
}

- (NSString *)navigationTitle
{
  return self.pageViewController.navigationItem.title;
}

- (void)setActivePhoto:(DFPeanutFeedObject *)photo inPhotos:(NSArray *)photos
{
  self.activePhoto = photo;
  self.photos = photos;
  [self showPhoto:photo];
}

- (void)showPhoto:(DFPeanutFeedObject *)photo
{
  if (self.pageViewController) {
    DFPhotoViewController *viewController = [[DFPhotoViewController alloc] init];
    viewController.photo = photo;
    [self.pageViewController setViewControllers:@[viewController]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:NO
                                     completion:nil];
  }
}

#pragma mark - DFMultiPhotoPageView datasource

- (UIViewController*)pageViewController:(UIPageViewController *)pageViewController
     viewControllerBeforeViewController:(UIViewController *)viewController
{
  if (self.photos) {
    NSInteger currentPhotoIndex = [self photoIndexForViewController:viewController];
    if (currentPhotoIndex <= 0 || currentPhotoIndex == NSNotFound) return nil;
    
    DFPeanutFeedObject *photoBefore = self.photos[currentPhotoIndex - 1];
    DFPhotoViewController *beforePVC = [[DFPhotoViewController alloc] init];
    beforePVC.photo = photoBefore;
    return beforePVC;
  }
  
  return nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.photos) {
    NSInteger currentPhotoIndex = [self photoIndexForViewController:viewController];
    if (currentPhotoIndex >= self.photos.count - 1 || currentPhotoIndex == NSNotFound) return nil;
    
    DFPeanutFeedObject *photoAfter = self.photos[currentPhotoIndex + 1];
    DFPhotoViewController *PVCAfter = [[DFPhotoViewController alloc] init];
    PVCAfter.photo = photoAfter;
    return PVCAfter;
  }
  
  return nil;
}

- (NSUInteger)photoIndexForViewController:(UIViewController *)viewController
{
  if (self.photos) {
    DFPhotoViewController *currentPVC = (DFPhotoViewController *)viewController;
    DFPeanutFeedObject *photo = currentPVC.photo;
    NSUInteger index = [self.photos indexOfObject:photo];
    return index;
  }
  
  return NSNotFound;
}

- (DFPhotoViewController *)currentPhotoViewController
{
  return self.pageViewController.viewControllers.firstObject;
}

- (void)pageViewController:(UIPageViewController *)pageViewController
willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
  if (pendingViewControllers.count > 0) {
    DFPhotoViewController *pvc = [pendingViewControllers firstObject];
    self.view.backgroundColor = [DFMultiPhotoViewController
                                 colorForTheatreModeEnabled:self.theatreModeEnabled];
    pvc.view.backgroundColor = [DFMultiPhotoViewController
                                colorForTheatreModeEnabled:self.theatreModeEnabled];
  }
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  if (completed) {
    self.activePhoto =
    self.photos[[self photoIndexForViewController:self.pageViewController.viewControllers.firstObject]];
  }
}

#pragma mark - Support for Theatre Mode

- (void)setTheatreModeEnabled:(BOOL)theatreModeEnabled
{
  [self setTheatreModeEnabled:theatreModeEnabled animated:NO];
}

- (void)setTheatreModeEnabled:(BOOL)theatreModeEnabled animated:(BOOL)animated
{
  if (theatreModeEnabled == _theatreModeEnabled) return;
  
  _theatreModeEnabled = theatreModeEnabled;
  
  NSTimeInterval duration;
  if (animated) {
    duration = 0.5;
  } else {
    duration = 0.0;
  }
  
  [UIView animateWithDuration:duration animations:^{
    self.hideStatusBar = theatreModeEnabled;
    [self.navigationController setNavigationBarHidden:theatreModeEnabled animated:animated];
    self.currentPhotoViewController.theatreModeEnabled = theatreModeEnabled;
    self.view.backgroundColor = [DFMultiPhotoViewController colorForTheatreModeEnabled:theatreModeEnabled];
    self.pageViewController.view.backgroundColor = [DFMultiPhotoViewController colorForTheatreModeEnabled:theatreModeEnabled];
  }];
}

+ (UIColor *)colorForTheatreModeEnabled:(BOOL)theatreModeEnabled
{
  if (theatreModeEnabled) {
    return [UIColor blackColor];
  } else {
    return [UIColor whiteColor];
  }
}

#pragma mark - Actions

- (void)backPressed:(id)sender
{
  [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - Status Bar Hiding


- (BOOL)prefersStatusBarHidden
{
  return self.hideStatusBar;
}

- (void)setHideStatusBar:(BOOL)hideStatusBar
{
  if (hideStatusBar != _hideStatusBar) {
    _hideStatusBar = hideStatusBar;
    [self setNeedsStatusBarAppearanceUpdate];
  }
}

@end
