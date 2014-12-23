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
#import "DFStrandConstants.h"
#import "DFPersonSelectionTableViewCell.h"
#import "DFFriendProfileViewController.h"
#import "UINib+DFHelpers.h"
#import "UIAlertView+DFHelpers.h"
#import "DFContactSyncManager.h"
#import "DFSelectPhotosViewController.h"
#import "DFNavigationController.h"
#import "DFNoTableItemsView.h"
#import "DFSeenStateManager.h"
#import "NSArray+DFHelpers.h"
#import "DFSettingsViewController.h"
#import "DFAnalytics.h"
#import "DFCreateStrandFlowViewController.h"
#import "DFInviteFriendViewController.h"
#import "DFActionButtonTableViewCell.h"


@interface DFFriendsViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *peanutDataManager;
@property (nonatomic, strong) NSArray *friendPeanutUsers;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) DFNoTableItemsView *noFriendsView;

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
  self.tabBarItem.title = @"Friends";
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/PeopleBarButtonSelected"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/PeopleBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithImage:[UIImage imageNamed:@"Assets/Icons/InviteBarButton"]
                                            style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(createButtonPressed:)];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithImage:[UIImage imageNamed:@"Assets/Icons/SettingsBarButton"]
                                           style:UIBarButtonItemStylePlain target:self
                                           action:@selector(settingsPressed:)];
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

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)configureTableView:(UITableView *)tableView
{
  tableView.dataSource = self;
  tableView.delegate = self;
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

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
}

#pragma mark - Data Refresh/Reload

- (void)refreshFromServer
{
  [self.peanutDataManager refreshInboxFromServer:^{
    [self.refreshControl endRefreshing];
    [self reloadData];
  }];
}

- (void)reloadData
{
  _friendPeanutUsers = [self.peanutDataManager friendsList];
  [self.tableView reloadData];
  [self configureNoResultsView];
}

- (void)configureTabBadge
{
  NSUInteger numWithUnseen = [self numPeopleWithUnseenSuggestions];
  if (numWithUnseen > 0) {
    self.tabBarItem.badgeValue = [@(numWithUnseen) stringValue];
  } else {
    self.tabBarItem.badgeValue = nil;
  }

}

- (void)configureNoResultsView
{
  if (self.friendPeanutUsers.count == 0) {
    if (!self.noFriendsView) {
      self.noFriendsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
      [self.noFriendsView setSuperView:self.tableView];
    }
    
    self.noFriendsView.hidden = NO;
    if ([[DFPeanutFeedDataManager sharedManager] hasInboxData]) {
      self.noFriendsView.titleLabel.text = @"No Friends Yet";
      [self.noFriendsView.activityIndicator stopAnimating];
    
    } else {
      self.noFriendsView.titleLabel.text = @"Loading...";
      [self.noFriendsView.activityIndicator startAnimating];
      self.noFriendsView.subtitleLabel.text = @"";
    }
    self.tableView.hidden = YES;
  } else {
    self.noFriendsView.hidden = YES;
    self.tableView.hidden = NO;
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (NSUInteger)numPeopleWithUnseenSuggestions
{
  NSUInteger result = 0;
  
  for (DFPeanutUserObject *peanutUser in self.friendPeanutUsers) {
    NSArray *unseenForUser = [self unseenPrivateStrandIDsForUser:peanutUser];
    if (unseenForUser.count > 0) result++;
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



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPersonSelectionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  cell.showsTickMarkWhenSelected = NO;
  [cell configureWithCellStyle:(DFPersonSelectionTableViewCellStyleStrandUser
                                | DFPersonSelectionTableViewCellStyleRightLabel)];
  DFPeanutUserObject *peanutUser = self.friendPeanutUsers[indexPath.row];
  
  cell.profilePhotoStackView.peanutUsers = @[peanutUser];
  cell.nameLabel.text = [peanutUser fullName];
  cell.nameLabel.font = [UIFont systemFontOfSize:cell.nameLabel.font.pointSize];
  cell.rightLabel.text = @"";
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  
  return cell;
}

- (NSArray *)unseenPrivateStrandIDsForUser:(DFPeanutUserObject *)peanutUser
{
  NSArray *unswappedStrandIDs = [[self.peanutDataManager privateStrandsWithUser:peanutUser]
                                 arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *privateStrand) {
                                   return @(privateStrand.id);
                                 }];
  NSMutableArray *unseenPrivateStrandIDs = [unswappedStrandIDs mutableCopy];
  NSArray *seenPrivateStrandIDs = [[DFSeenStateManager sharedManager] seenPrivateStrandIDsForUser:peanutUser];
  [unseenPrivateStrandIDs removeObjectsInArray:seenPrivateStrandIDs];
  return unseenPrivateStrandIDs;
}


#pragma mark - Action Handler Helpers

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutUserObject *user = self.friendPeanutUsers[indexPath.row];
  
  DFFriendProfileViewController *profileView = [[DFFriendProfileViewController alloc] initWithPeanutUser:user];
  [self.navigationController pushViewController:profileView animated:YES];
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (void)createButtonPressed:(id)sender
{
  DFInviteFriendViewController *inviteController = [[DFInviteFriendViewController alloc] init];
  [self presentViewController:inviteController animated:YES completion:nil];
}

- (void)settingsPressed:(id)sender
{
  [DFSettingsViewController presentModallyInViewController:self];
}

@end
