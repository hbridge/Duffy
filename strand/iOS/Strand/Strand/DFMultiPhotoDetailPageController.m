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
  return [self detailViewControllerAscending:YES
                    fromDetailViewController:(DFPhotoDetailViewController *)viewController];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerBeforeViewController:(UIViewController *)viewController
{
  return [self detailViewControllerAscending:NO
                    fromDetailViewController:(DFPhotoDetailViewController *)viewController];
}

- (UIViewController *)detailViewControllerAscending:(BOOL)ascending fromDetailViewController:(DFPhotoDetailViewController *)detailViewController
{
  DFPeanutFeedObject *photoObject = detailViewController.photoObject;
  NSUInteger index = [DFPeanutFeedObject indexOfFeedObject:photoObject inArray:self.photos];
  index = index + (ascending ? 1 : - 1);
  if (index >= self.photos.count) return nil;
  DFPeanutFeedObject *afterPhoto = self.photos[index];
  return [self detailViewControllerForPhotoObject:afterPhoto
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
