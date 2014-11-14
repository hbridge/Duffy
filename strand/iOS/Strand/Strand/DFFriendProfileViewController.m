//
//  DFFriendProfileViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFriendProfileViewController.h"
#import "DFGalleryViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "UIDevice+DFHelpers.h"
#import "DFSwapViewController.h"

@interface DFFriendProfileViewController ()

@property (nonatomic, retain) DFSwapViewController *unsharedViewController;
@property (nonatomic, retain) DFGalleryViewController *sharedGalleryViewController;

@end

@implementation DFFriendProfileViewController


- (instancetype)initWithPeanutUser:(DFPeanutUserObject *)peanutUser
{
  self = [super init];
  if (self) {
    _peanutUser = peanutUser;
    _unsharedViewController = [[DFSwapViewController alloc]
                               initWithUserToFilter:peanutUser];
    _sharedGalleryViewController = [[DFGalleryViewController alloc]
                                    initWithFilterUser:peanutUser];
    
    // set their parent view controller so they inherit the nav controller etc
    [self displayContentController:_sharedGalleryViewController];
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
  NSArray *swappedStrands = [[DFPeanutFeedDataManager sharedManager]
                             acceptedStrandsWithPostsCollapsed:YES
                             filterToUser:self.peanutUser.id
                             feedObjectSortKey:@"time_taken"
                             ascending:YES];
  self.profilePhotoStackView.peanutUsers = @[self.peanutUser];
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];
  self.nameLabel.text = [self.peanutUser fullName];
  self.subtitleLabel.text = [NSString stringWithFormat:@"%d shared",
                             (int)swappedStrands.count];
  [self.tabSegmentedControl setTitle:[NSString stringWithFormat:@"Suggestions"]
                   forSegmentAtIndex:1];
  
  // add a fancy background blur if iOS8 +
  if ([UIDevice majorVersionNumber] >= 8) {
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:
                                            
                                            [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.tabSegmentedControlWrapper.frame.origin.y + self.tabSegmentedControlWrapper.frame.size.height);
    visualEffectView.frame = frame;
    [self.view insertSubview:visualEffectView belowSubview:self.headerView];
    [visualEffectView.contentView addSubview:self.headerView];
    [visualEffectView.contentView addSubview:self.tabSegmentedControlWrapper];
    
    self.headerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    self.tabSegmentedControlWrapper.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
  }
}

- (void) displayContentController: (UIViewController*) contentController;
{
  [self addChildViewController:contentController];
  contentController.view.frame = self.view.frame;
  //[self configureContentControllerView:contentController];
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
  CGFloat contentTop = self.tabSegmentedControlWrapper.frame.origin.y
  + self.tabSegmentedControlWrapper.frame.size.height;
  UIEdgeInsets insets = UIEdgeInsetsMake(contentTop, 0, 0, 0);
  mainView.contentInset = insets;
  mainView.contentOffset = CGPointMake(0, -contentTop);
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
- (IBAction)segmentViewValueChanged:(UISegmentedControl *)sender {
  if (sender.selectedSegmentIndex == 0) {
    [self hideContentController:self.unsharedViewController];
    [self displayContentController:self.sharedGalleryViewController];
  } else {
    [self hideContentController:self.sharedGalleryViewController];
    [self displayContentController:self.unsharedViewController];
  }
}


- (IBAction)backButtonPressed:(id)sender {
  [self.navigationController popViewControllerAnimated:YES];
}

@end
