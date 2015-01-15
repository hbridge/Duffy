//
//  DFFriendProfileViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFriendProfileViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "UIDevice+DFHelpers.h"
#import "DFGalleryViewController.h"

@interface DFFriendProfileViewController ()

@property (nonatomic, retain) DFGalleryViewController *galleryViewController;

@end

@implementation DFFriendProfileViewController


- (instancetype)initWithPeanutUser:(DFPeanutUserObject *)peanutUser
{
  self = [super init];
  if (self) {
    _peanutUser = peanutUser;
    _galleryViewController = [[DFGalleryViewController alloc] initWithFilterUser:peanutUser];
    // set their parent view controller so they inherit the nav controller etc
    [self displayContentController:_galleryViewController];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self configureHeader];
}

- (BOOL)hidesBottomBarWhenPushed
{
  return YES;
}

- (void)configureHeader
{
  [self.backButton setImage:[self.backButton.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                   forState:UIControlStateNormal];
  
  self.profilePhotoStackView.peanutUsers = @[self.peanutUser];
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];

  self.nameLabel.text = [self.peanutUser fullName];
  self.subtitleLabel.text = [NSString stringWithFormat:@"%lu shared",
                             (unsigned long)[self.galleryViewController photosInGalleryCount]];
  
  // add a fancy background blur if iOS8 +
  if ([UIDevice majorVersionNumber] >= 8) {
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:
                                            
                                            [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.headerView.frame.size.height);
    visualEffectView.frame = frame;
    [self.view insertSubview:visualEffectView belowSubview:self.headerView];
    [visualEffectView.contentView addSubview:self.headerView];
    
    //self.headerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
  }
}
- (void) displayContentController: (UIViewController*) contentController;
{
  [self addChildViewController:contentController];
  contentController.view.frame = self.view.frame;
  [self.view insertSubview:contentController.view atIndex:0];
  [contentController didMoveToParentViewController:self];
}

- (void) hideContentController: (UIViewController*) contentController
{
  [contentController willMoveToParentViewController:nil];
  [contentController.view removeFromSuperview];
  [contentController removeFromParentViewController];
}

- (void)configureContentControllerView:(UIViewController *)viewController
{
  UIScrollView *mainView = [self mainScrollViewForViewController:viewController];
  mainView.frame = self.view.frame;
  CGFloat contentTop = self.headerView.frame.size.height;
  UIEdgeInsets insets = UIEdgeInsetsMake(contentTop, 0, 0, 0);
  mainView.contentInset = insets;
}

- (UIScrollView *)mainScrollViewForViewController:(UIViewController *)viewController
{
  if ([viewController respondsToSelector:@selector(tableView)]) {
    return [(UITableViewController *)viewController tableView];
  } else if ([viewController respondsToSelector:@selector(collectionView)]) {
    return [(UICollectionViewController *)viewController collectionView];
  }
  return nil;
}


- (void)viewDidLayoutSubviews
{
  //set insets etc
  UITableViewController *currentContoller = self.childViewControllers.firstObject;
  [self configureContentControllerView:currentContoller];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self markSuggestionsSeen];
}

- (void)markSuggestionsSeen
{
  
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:YES];
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (IBAction)backButtonPressed:(id)sender {
  [self.navigationController popViewControllerAnimated:YES];
}

@end
