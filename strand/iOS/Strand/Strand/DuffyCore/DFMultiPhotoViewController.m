//
//  DFMultiPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFMultiPhotoViewController.h"
#import "DFAnalytics.h"
#import "DFPhoto.h"
#import "DFPhotoViewController.h"

@interface DFMultiPhotoViewController ()

@property (nonatomic) NSUInteger currentPhotoIndex;
@property (nonatomic, retain) NSArray *photos;
@property (nonatomic) BOOL hideStatusBar;

@end

@implementation DFMultiPhotoViewController


- (id)init
{
    self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                    navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                  options:@{UIPageViewControllerOptionInterPageSpacingKey:[NSNumber numberWithFloat:40.0]}];
    if (self) {
        self.delegate = self;
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)setActivePhoto:(DFPhoto *)photo inPhotos:(NSArray *)photos
{
  self.dataSource = self;
  self.photos = photos;
  DFPhotoViewController *viewController = [[DFPhotoViewController alloc] init];
  viewController.photo = photo;
  [self setViewControllers:@[viewController]
                 direction:UIPageViewControllerNavigationDirectionForward
                  animated:NO
                completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
  
  UIBarButtonItem *actionItem = [[UIBarButtonItem alloc]
                                 initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                 target:self
                                 action:@selector(actionButtonClicked:)];
  self.navigationItem.rightBarButtonItem = actionItem;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:YES];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
  
    [DFAnalytics logViewController:self disappearedWithParameters:nil];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (DFPhotoViewController *)currentPhotoViewController
{
    return self.viewControllers.firstObject;
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  if (completed) {
    [DFAnalytics logSwitchBetweenPhotos:DFAnalyticsActionTypeSwipe];
  }
}


#pragma mark - DFMultiPhotoPageView datasource

- (UIViewController*)pageViewController:(UIPageViewController *)pageViewController
     viewControllerBeforeViewController:(UIViewController *)viewController
{
  if (self.photos) {
    NSInteger currentPhotoIndex = [self photoIndexForViewController:viewController];
    if (currentPhotoIndex <= 0 || currentPhotoIndex == NSNotFound) return nil;
    
    DFPhoto *photoBefore = self.photos[currentPhotoIndex - 1];
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
    
    DFPhoto *photoAfter = self.photos[currentPhotoIndex + 1];
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
    DFPhoto *photo = currentPVC.photo;
    NSUInteger index = [self.photos indexOfObject:photo];
    return index;
  }
  
  return NSNotFound;
}

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
    self.currentPhotoViewController.view.backgroundColor =
    [self colorForTheatreModeEnabled:theatreModeEnabled];
    self.view.backgroundColor = [self colorForTheatreModeEnabled:theatreModeEnabled];
  }];
}

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
  if (pendingViewControllers.count > 0) {
    DFPhotoViewController *pvc = [pendingViewControllers firstObject];
    pvc.view.backgroundColor = [self colorForTheatreModeEnabled:self.theatreModeEnabled];
  }
}

- (UIColor *)colorForTheatreModeEnabled:(BOOL)theatreModeEnabled
{
  if (theatreModeEnabled) {
    return [UIColor blackColor];
  } else {
    return [UIColor whiteColor];
  }
}

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

- (void)actionButtonClicked:(id)sender
{
  [self.currentPhotoViewController showPhotoActions:sender];
}


@end
