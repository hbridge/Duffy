//
//  DFFriendProfileViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFriendProfileViewController.h"
#import "DFSingleFriendViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "UIDevice+DFHelpers.h"
#import "DFSwapViewController.h"

@interface DFFriendProfileViewController ()

@property (nonatomic, retain) DFSwapViewController *unsharedViewController;
@property (nonatomic, retain) DFSingleFriendViewController *sharedViewController;

@end

@implementation DFFriendProfileViewController


- (instancetype)initWithPeanutUser:(DFPeanutUserObject *)peanutUser
{
  self = [super init];
  if (self) {
    _peanutUser = peanutUser;
    _unsharedViewController = [[DFSwapViewController alloc]
                               initWithUserToFilter:peanutUser];
    _sharedViewController = [[DFSingleFriendViewController alloc]
                               initWithUser:peanutUser
                               withSharedPhotos:YES];
    
    // set their parent view controller so they inherit the nav controller etc
    [self displayContentController:_sharedViewController];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self configureHeader];
}

- (void)configureHeader
{
  NSArray *swappedStrands = [[DFPeanutFeedDataManager sharedManager]
                             publicStrandsWithUser:self.peanutUser includeInvites:NO];
  NSArray *unswappedStrands = [[DFPeanutFeedDataManager sharedManager]
                               privateStrandsWithUser:self.peanutUser];
  self.profilePhotoStackView.names = @[self.peanutUser.display_name];
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];
  self.nameLabel.text = self.peanutUser.display_name;
  self.subtitleLabel.text = [NSString stringWithFormat:@"%d shared",
                             (int)swappedStrands.count];
  [self.tabSegmentedControl setTitle:[NSString stringWithFormat:@"Suggestions (%d)",
                                      (int)unswappedStrands.count]
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
  [self configureContentControllerTableView:(UITableViewController *)contentController];
  [self.view insertSubview:contentController.view atIndex:0];
  [contentController didMoveToParentViewController:self];
}

- (void) hideContentController: (UIViewController*) contentController
{
  [contentController willMoveToParentViewController:nil];
  [contentController.view removeFromSuperview];
  [contentController removeFromParentViewController];
}

- (void)configureContentControllerTableView:(UITableViewController *)tableViewController
{
  tableViewController.tableView.frame = self.view.frame;
}


- (void)viewDidLayoutSubviews
{
  //set insets etc
  UITableViewController *currentContoller = self.childViewControllers.firstObject;
  UITableView *tableView = currentContoller.tableView;
  CGFloat contentTop = self.tabSegmentedControlWrapper.frame.origin.y
  + self.tabSegmentedControlWrapper.frame.size.height;
  UIEdgeInsets insets = UIEdgeInsetsMake(contentTop, 0, 0, 0);
  tableView.contentInset = insets;
  tableView.contentOffset = CGPointMake(0, -contentTop);
  tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
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
    [self displayContentController:self.sharedViewController];
  } else {
    [self hideContentController:self.sharedViewController];
    [self displayContentController:self.unsharedViewController];
  }
}


- (IBAction)backButtonPressed:(id)sender {
  [self.navigationController popViewControllerAnimated:YES];
}

@end
