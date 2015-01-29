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
    DFPhotoDetailViewController *pdvc = [self detailViewControllerForPhotoObject:photo];
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
}

- (DFPhotoDetailViewController *)detailViewControllerForPhotoObject:(DFPeanutFeedObject *)photoObject
{
  DFPhotoDetailViewController *pdvc = [[DFPhotoDetailViewController alloc]
                                       initWithPhotoObject:photoObject];
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
  return [self detailViewControllerForPhotoObject:afterPhoto];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
  DFPhotoDetailViewController *detailViewController = (DFPhotoDetailViewController *)viewController;
  DFPeanutFeedObject *photoObject = detailViewController.photoObject;
  DFPeanutFeedObject *beforePhoto = [self.photos objectBeforeObject:photoObject wrap:NO];
  if (!beforePhoto) return nil;
  return [self detailViewControllerForPhotoObject:beforePhoto];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
