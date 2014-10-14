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
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)configureTableView:(UITableView *)tableView
{
  [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];

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
  NSString *swappedTitle = [NSString stringWithFormat:@"Swapped (%lu)", (unsigned long)swappedStrands.count];
  NSString *unswappedTitle = [NSString stringWithFormat:@"To Swap (%lu)", (unsigned long)unswappedStrands.count];
  
  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:swappedTitle, unswappedTitle, nil];
  
  
  [actionSheet showInView:self.tableView];
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  
  DFPeanutUserObject *peanutUser = self.friendPeanutUsers[indexPath.row];
  cell.textLabel.text = peanutUser.display_name;
  return cell;
}


#pragma mark - Action Handler Helpers

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
  DDLogVerbose(@"The %@ button was tapped.", buttonTitle);

  if (buttonIndex == 0) {
    DFSingleFriendViewController *vc = [[DFSingleFriendViewController alloc] initWithUser:self.actionSheetUserSelected];
    [self.navigationController pushViewController:vc animated:YES];
  }
}


@end
