//
//  DFMutliPhotoDetailPageController.m
//  Strand
//
//  Created by Henry Bridge on 12/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFMultiPhotoDetailPageController.h"
#import "DFPhotoDetailViewController.h"
#import "DFPeanutFeedDataManager.h"

@interface DFMultiPhotoDetailPageController ()

@end

@implementation DFMultiPhotoDetailPageController

- (instancetype)initWithCurrentPhoto:(DFPeanutFeedObject *)photo inPhotos:(NSArray *)photos
{
  self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                  navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                options:@{UIPageViewControllerOptionInterPageSpacingKey :@(20)}];
  if (self) {
    _photos = photos;
    DFPhotoDetailViewController *pdvc = [self detailViewControllerForPhotoObject:photo
                                                              theatreModeEnabled:NO];
    if (pdvc)
      [self setViewControllers:@[pdvc]
                     direction:UIPageViewControllerNavigationDirectionForward
                      animated:NO
                    completion:nil];
  }
  
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.dataSource = self;
  self.delegate = self;
  self.view.backgroundColor = [UIColor whiteColor];
}

- (DFPhotoDetailViewController *)detailViewControllerForPhotoObject:(DFPeanutFeedObject *)photoObject
                                                 theatreModeEnabled:(BOOL)theatreModeEnabled
{
  DFPhotoDetailViewController *pdvc = [[DFPhotoDetailViewController alloc]
                                       initWithPhotoObject:photoObject];
  pdvc.theatreModeEnabled = theatreModeEnabled;
  return pdvc;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
  DFPhotoDetailViewController *detailViewController = (DFPhotoDetailViewController *)viewController;
  DFPeanutFeedObject *photoObject = detailViewController.photoObject;
  DFPeanutFeedObject *afterPhoto = [self.photos objectAfterObject:photoObject wrap:NO];
  if (!afterPhoto) return nil;
  return [self detailViewControllerForPhotoObject:afterPhoto
                               theatreModeEnabled:detailViewController.theatreModeEnabled];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  DFPhotoDetailViewController *detailViewController = (DFPhotoDetailViewController *)viewController;
  DFPeanutFeedObject *photoObject = detailViewController.photoObject;
  DFPeanutFeedObject *beforePhoto = [self.photos objectBeforeObject:photoObject wrap:NO];
  if (!beforePhoto) return nil;
  return [self detailViewControllerForPhotoObject:beforePhoto
          theatreModeEnabled:detailViewController.theatreModeEnabled];
}

- (void)pageViewController:(UIPageViewController *)pageViewController
willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
  BOOL theatreModeEnabled = ((DFPhotoDetailViewController*)self.viewControllers.firstObject).theatreModeEnabled;
  for (DFPhotoDetailViewController *detailPVC in pendingViewControllers) {
    //sometimes the PVC caches view controllers, so make sure we set the value before it transitions
    detailPVC.theatreModeEnabled = theatreModeEnabled;
  }
  
  if (theatreModeEnabled) self.view.backgroundColor = [UIColor blackColor];
  else self.view.backgroundColor = [UIColor whiteColor];
}

@end
