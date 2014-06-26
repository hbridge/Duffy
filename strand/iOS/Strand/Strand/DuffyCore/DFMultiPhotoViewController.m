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
@property (nonatomic, retain) NSArray *photoURLs;

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

- (id)initWithActivePhoto:(DFPhoto *)photo inPhotos:(NSArray *)photos
{
  self = [self init];
  if (self) {
    self.photos = photos;
    self.dataSource = self;
  }
  
  return self;
}

- (id)initWithActivePhotoURL:(NSURL *)url inURLs:(NSArray *)photoURLs
{
  self = [self init];
  if (self) {
    self.photoURLs = photoURLs;
    self.dataSource = self;
  }
  
  return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
  
  UIBarButtonItem *actionItem = [[UIBarButtonItem alloc]
                                 initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                 target:self
                                 action:@selector(actionButtonClicked:)];
  self.navigationItem.rightBarButtonItem = actionItem;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  if (self.photos) {
    DFPhoto *photo = [self.photos objectAtIndex:self.currentPhotoIndex];
    pvc.photo = photo;
  } else if (self.photoURLs) {
    NSURL *photoURL = self.photoURLs[self.currentPhotoIndex];
    pvc.photoURL = photoURL;
  }
  return pvc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  if (self.currentPhotoIndex < self.photos.count - 1) {
    self.currentPhotoIndex += 1;
  } else {
    self.currentPhotoIndex = 0;
  }
  
  DFPhoto *photo = [self.photos objectAtIndex:self.currentPhotoIndex];
  DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
  pvc.photo = photo;
  return pvc;
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
