//
//  DFMultiPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/26/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFMultiPhotoViewController.h"

@interface DFMultiPhotoViewController ()

@end

@implementation DFMultiPhotoViewController


- (id)init
{
    self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                    navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                  options:nil];
    if (self) {
        self.delegate = self;
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    NSLog(@"Multi-photo view controller received memory warning.");
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
    // todo: cache next photo controller on first load.

}

@end
