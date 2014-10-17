//
//  DFFriendsViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFriendsViewController.h"
#import <AddressBook/AddressBook.h>
#import "DFPeanutFeedDataManager.h"
#import "DFPeanutUserObject.h"
#import "DFSingleFriendViewController.h"
#import "DFStrandConstants.h"
#import "DFPersonSelectionTableViewCell.h"
#import "DFFriendProfileViewController.h"
#import "DFSwapUpsellView.h"
#import "UINib+DFHelpers.h"
#import "UIAlertView+DFHelpers.h"
#import "DFContactSyncManager.h"


@interface DFFriendsViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *peanutDataManager;
@property (nonatomic, strong) NSArray *friendPeanutUsers;
@property (nonatomic, retain) UIRefreshControl *refreshControl;

@property (nonatomic, retain) DFPeanutUserObject *actionSheetUserSelected;
@property (nonatomic, retain) DFSwapUpsellView *contactsUpsellView;

@end

@implementation DFFriendsViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureTabAndNav];
    self.peanutDataManager = [DFPeanutFeedDataManager sharedManager];
    [self observeNotifications];
  }
  return self;
}

- (void)configureTabAndNav
{
  self.navigationItem.title = @"Friends";
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/PeopleBarButton"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/PeopleBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

}


- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewPrivatePhotosDataNotificationName
                                             object:nil];
}


- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureTableView:self.tableView];
  [self configureContactsUpsell];
}

- (void)configureTableView:(UITableView *)tableView
{
  [tableView registerNib:[UINib nibWithNibName:@"DFPersonSelectionTableViewCell" bundle:nil]
  forCellReuseIdentifier:@"cell"];
  
  [self configureRefreshControl];
  
  UITableViewController *mockTVC = [[UITableViewController alloc] init];
  mockTVC.tableView = tableView;
  mockTVC.refreshControl = self.refreshControl;
}

- (void)configureRefreshControl
{
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
}

- (void)configureContactsUpsell
{
  ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
  if (status != kABAuthorizationStatusAuthorized) {
    // ask for contacts
    if (!self.contactsUpsellView) {
      self.contactsUpsellView = [UINib instantiateViewWithClass:[DFSwapUpsellView class]];
      [self.view addSubview:self.contactsUpsellView];
      [self.contactsUpsellView configureForContactsWithError:(status != kABAuthorizationStatusNotDetermined)
                                                buttonTarget:self
                                                    selector:@selector(contactsUpsellButtonPressed:)];
    }
    CGFloat swapUpsellHeight = self.view.frame.size.height * .66;
    self.contactsUpsellView.frame = CGRectMake(0,
                                           self.view.frame.size.height - swapUpsellHeight,
                                           self.view.frame.size.width,
                                           swapUpsellHeight);
  } else {
    [self.contactsUpsellView removeFromSuperview];
  }
}

- (void)contactsUpsellButtonPressed:(id)sender
{
  if (ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusNotDetermined) {
    [DFContactSyncManager showContactsDeniedAlert];
    return;
  }
  [DFContactSyncManager askForContactsPermissionWithSuccess:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
       object:self];
      self.contactsUpsellView.hidden = YES;
      [self.contactsUpsellView removeFromSuperview];
    });
  } failure:^(NSError *error) {
    [self.contactsUpsellView removeFromSuperview];
    self.contactsUpsellView = nil;
    [self configureContactsUpsell];
  }];
}

#pragma mark - Data Refresh/Reload

- (void)refreshFromServer
{
  [self.peanutDataManager refreshInboxFromServer:^{
    [self.refreshControl endRefreshing];
  }];
}

- (void)reloadData
{
  _friendPeanutUsers = [self.peanutDataManager friendsList];
  [self.tableView reloadData];
  NSUInteger numWithUnshared = [self numPeopleWithUnsharedStrands];
  if (numWithUnshared > 0) {
    self.tabBarItem.badgeValue = [@(numWithUnshared) stringValue];
  } else {
    self.tabBarItem.badgeValue = nil;
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (NSUInteger)numPeopleWithUnsharedStrands
{
  NSUInteger result = 0;
  
  for (DFPeanutUserObject *peanutUser in self.friendPeanutUsers) {
    NSArray *unswappedForUser = [self.peanutDataManager privateStrandsWithUser:peanutUser];
    if (unswappedForUser.count > 0) result++;
  }
  
  return result;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.friendPeanutUsers.count;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutUserObject *user = self.friendPeanutUsers[indexPath.row];
  self.actionSheetUserSelected = user;
  
  DFFriendProfileViewController *profileView = [[DFFriendProfileViewController alloc] initWithPeanutUser:user];
  [self.navigationController pushViewController:profileView animated:YES];
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPersonSelectionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  cell.showsTickMarkWhenSelected = NO;
  [cell configureWithCellStyle:DFPersonSelectionTableViewCellStyleStrandUserWithRightLabel];
  DFPeanutUserObject *peanutUser = self.friendPeanutUsers[indexPath.row];
  NSArray *unswappedStrands = [self.peanutDataManager privateStrandsWithUser:peanutUser];
  
  cell.profilePhotoStackView.names = @[peanutUser.display_name];
  cell.nameLabel.text = peanutUser.display_name;
  int unswappedCount = (int)unswappedStrands.count;
  if (unswappedCount > 0) {
    cell.rightLabel.text = [NSString stringWithFormat:@"%d to swap", unswappedCount];
    cell.nameLabel.font = [UIFont boldSystemFontOfSize:cell.nameLabel.font.pointSize];
  } else {
    cell.nameLabel.font = [UIFont systemFontOfSize:cell.nameLabel.font.pointSize];
    cell.rightLabel.text = @"";
  }
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  
  return cell;
}


#pragma mark - Action Handler Helpers

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
  DDLogVerbose(@"The %@ button was tapped.", buttonTitle);

  if (buttonIndex == 0) {
    DFSingleFriendViewController *vc = [[DFSingleFriendViewController alloc] initWithUser:self.actionSheetUserSelected withSharedPhotos:YES];
    [self.navigationController pushViewController:vc animated:YES];
  } else if (buttonIndex == 1) {
    DFSingleFriendViewController *vc = [[DFSingleFriendViewController alloc] initWithUser:self.actionSheetUserSelected withSharedPhotos: NO];
    [self.navigationController pushViewController:vc animated:YES];
  }
}


@end
