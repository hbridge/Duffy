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
#import "DFGalleryWebViewController.h"

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
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
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
    self.currentPhotoViewController.theatreModeEnabled = theatreModeEnabled;
    self.view.backgroundColor = [DFMultiPhotoViewController colorForTheatreModeEnabled:theatreModeEnabled];
  }];
}

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
  if (pendingViewControllers.count > 0) {
    DFPhotoViewController *pvc = [pendingViewControllers firstObject];
    pvc.view.backgroundColor = [DFMultiPhotoViewController
                                colorForTheatreModeEnabled:self.theatreModeEnabled];
  }
}

+ (UIColor *)colorForTheatreModeEnabled:(BOOL)theatreModeEnabled
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

- (void)activePhotoDeleted
{
  // If the root view contorller is the gallery, pop back to the gallery
  UIViewController *rootViewController = self.navigationController.viewControllers.firstObject;
  
  if ([[rootViewController class] isSubclassOfClass:[DFGalleryWebViewController class]]) {
    [self.navigationController popViewControllerAnimated:YES];
    return;
  }
  
  // Otherwise, if the root view controller is the multi photo view controller, this is
  // The last photo view, so move the the most recent other photo taken or pop back to camera.
  
  DFPhoto *photo = self.currentPhotoViewController.photo;
  UIViewController *previousViewController = [self.dataSource pageViewController:self viewControllerBeforeViewController:self.currentPhotoViewController];
  UIViewController *nextViewController = [self.dataSource
                                          pageViewController:self
                                          viewControllerAfterViewController:self.currentPhotoViewController];
  if (previousViewController) {
    [self setViewControllers:@[previousViewController]
                   direction:UIPageViewControllerNavigationDirectionReverse
                    animated:YES
                  completion:nil];
  } else if (nextViewController) {
    [self setViewControllers:@[nextViewController]
                   direction:UIPageViewControllerNavigationDirectionForward
                    animated:YES
                  completion:nil];
  } else {
      [self.navigationController dismissViewControllerAnimated:YES completion:nil];
  }
  
  if (self.photos) {
    NSMutableArray *mutablePhotos = self.photos.mutableCopy;
    [mutablePhotos removeObject:photo];
    self.photos = mutablePhotos;
  }
}

@end
