//
//  DFFriendsViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFriendsViewController.h"

#import "DFPeanutFeedDataManager.h"
#import "DFPeanutUserObject.h"
#import "DFSingleFriendViewController.h"
#import "DFStrandConstants.h"
#import "DFPersonSelectionTableViewCell.h"
#import "DFFriendProfileViewController.h"


@interface DFFriendsViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *peanutDataManager;
@property (nonatomic, strong) NSArray *friendPeanutUsers;
@property (nonatomic, retain) UIRefreshControl *refreshControl;

@property (nonatomic, retain) DFPeanutUserObject *actionSheetUserSelected;

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
}


- (void)configureRefreshControl
{
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
}

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
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
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
  NSArray *swappedStrands = [self.peanutDataManager publicStrandsWithUser:user];
  NSArray *unswappedStrands = [self.peanutDataManager privateStrandsWithUser:user];
//  NSString *swappedTitle = [NSString stringWithFormat:@"Swapped (%lu)", (unsigned long)swappedStrands.count];
//  NSString *unswappedTitle = [NSString stringWithFormat:@"To Swap (%lu)", (unsigned long)unswappedStrands.count];
  
  DFFriendProfileViewController *profileView = [[DFFriendProfileViewController alloc] initWithPeanutUser:user];
  [self.navigationController pushViewController:profileView animated:YES];
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPersonSelectionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  cell.showsTickMarkWhenSelected = NO;
  [cell configureWithCellStyle:DFPersonSelectionTableViewCellStyleStrandUserWithSubtitle];
  DFPeanutUserObject *peanutUser = self.friendPeanutUsers[indexPath.row];
  NSArray *unswappedStrands = [self.peanutDataManager privateStrandsWithUser:peanutUser];
  
  cell.profilePhotoStackView.names = @[peanutUser.display_name];
  cell.nameLabel.text = peanutUser.display_name;
  cell.subtitleLabel.text = [NSString stringWithFormat:@"%d to Swap", (int)unswappedStrands.count];
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
