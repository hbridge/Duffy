//
//  DFSelectableMultiPhotoViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectableMultiPhotoViewController.h"

@interface DFSelectableMultiPhotoViewController ()

@end

@implementation DFSelectableMultiPhotoViewController

- (instancetype)initWithActivePhoto:(DFPeanutFeedObject *)photo
                  inSection:(NSUInteger)section
   ofSelectPhotosController:(DFSelectPhotosController *)selectPhotosController
{
  self = [super init];
  if (self) {
    _selectPhotosController = selectPhotosController;
    NSArray *photos = [selectPhotosController photosForSection:section];
    [super setActivePhoto:photo inPhotos:photos];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self setRightNavItem];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray *)previousViewControllers
       transitionCompleted:(BOOL)completed
{
  [super pageViewController:pageViewController
         didFinishAnimating:finished
    previousViewControllers:previousViewControllers
        transitionCompleted:completed];
  
  self.pageViewController.navigationItem.rightBarButtonItem.image = nil;
  if (!finished) return;
  
  [self setRightNavItem];
}

- (void)setRightNavItem
{
  BOOL currentlySelected = [self.selectPhotosController.selectedFeedObjects containsObject:self.activePhoto];
  if (!self.pageViewController.navigationItem.rightBarButtonItem) {
    self.pageViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                                 initWithImage:nil
                                                                 style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(toggleCurrentPhotoSelected:)];
  }
  
  if (!currentlySelected) {
    self.pageViewController.navigationItem.rightBarButtonItem.image = [UIImage imageNamed:@"Assets/Icons/PhotoNotSelectedNavButton"];
  } else {
    self.pageViewController.navigationItem.rightBarButtonItem.image = [UIImage imageNamed:@"Assets/Icons/PhotoSelectedNavButton"];
  }
}

- (void)toggleCurrentPhotoSelected:(id)sender
{
  [self.selectPhotosController toggleObjectSelected:self.activePhoto];
  [self setRightNavItem];
}


@end
