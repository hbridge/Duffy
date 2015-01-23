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
#import <SVProgressHUD/SVProgressHUD.h>

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
  [self.headerView setTintColor:[DFStrandConstants defaultBarForegroundColor]];
  [self.backButton setImage:[self.backButton.imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                   forState:UIControlStateNormal];
  
  self.profilePhotoStackView.peanutUsers = @[self.peanutUser];
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];

  self.nameLabel.text = [self.peanutUser fullName];
  [self reloadHeaderData];
  
  // add a fancy background blur if iOS8 +
  if ([UIDevice majorVersionNumber] >= 8) {
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:
                                            
                                            [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.headerView.frame.size.height);
    visualEffectView.frame = frame;
    [self.view insertSubview:visualEffectView belowSubview:self.headerView];
    [visualEffectView.contentView addSubview:self.headerView];
    
    // friend button
    self.friendButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    
    [self configureFriendButton:[[DFPeanutFeedDataManager sharedManager] isUserFriend:self.peanutUser.id]];
  }
}

- (void)configureFriendButton:(BOOL)isUserFriended
{
  if (isUserFriended) {
    [self.friendButton setTitle:@"Friend" forState:UIControlStateNormal];
    [self.friendButton setImage:[UIImage imageNamed:@"Assets/Icons/ToggleButtonCheck"] forState:UIControlStateNormal];
  } else {
    [self.friendButton setTitle:@"Add" forState:UIControlStateNormal];
    [self.friendButton setImage:[UIImage imageNamed:@"Assets/Icons/ToggleButtonPlus"] forState:UIControlStateNormal];
  }
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadHeaderData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)reloadHeaderData
{
  self.subtitleLabel.text = [NSString stringWithFormat:@"%lu shared",
                             (unsigned long)[self.galleryViewController photosInGalleryCount]];
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
  if (self.navigationController.viewControllers.firstObject == self) {
    [self dismissViewControllerAnimated:YES completion:nil];
  } else {
    [self.navigationController popViewControllerAnimated:YES];
  }
}

- (IBAction)friendButtonPressed:(id)sender {
  BOOL isFriends = [[DFPeanutFeedDataManager sharedManager] isUserFriend:self.peanutUser.id];
  BOOL newFriendValue = !isFriends;
  [SVProgressHUD show];
  [[DFPeanutFeedDataManager sharedManager]
   setUser:[[DFUser currentUser] userID]
   isFriends:newFriendValue
   withUserIDs:@[@(self.peanutUser.id)]
   success:^{
     dispatch_async(dispatch_get_main_queue(), ^{
       if (newFriendValue) {
         [SVProgressHUD showSuccessWithStatus:@"Added Friend!"];
       } else {
         [SVProgressHUD showSuccessWithStatus:@"Removed Friend"];
       }
       [self configureFriendButton:newFriendValue];
     });
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"Error: %@",
                                         error.localizedDescription]];
   }];
  
}

@end
