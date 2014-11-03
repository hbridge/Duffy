//
//  DFStrandsFeedViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInboxViewController.h"

#import "MMPopLabel.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "SVProgressHUD.h"
#import "NSString+DFHelpers.h"
#import "DFFeedViewController.h"
#import "DFImageManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFInboxTableViewCell.h"
#import "DFCardTableViewCell.h"
#import "DFNavigationController.h"
#import "DFPeanutFeedObject.h"
#import "DFPeanutFeedAdapter.h"
#import "DFPeanutUserObject.h"
#import "DFSelectPhotosController.h"
#import "DFStrandConstants.h"
#import "DFSelectPhotosViewController.h"
#import "DFStrandGalleryTitleView.h"
#import "DFStrandGalleryViewController.h"
#import "DFFeedViewController.h"
#import "DFNoTableItemsView.h"
#import "UINib+DFHelpers.h"
#import "DFPushNotificationsManager.h"
#import "DFAnalytics.h"
#import "DFCreateStrandFlowViewController.h"


@interface DFInboxViewController ()

@property (nonatomic, retain) DFPeanutFeedDataManager *manager;
@property (readonly, nonatomic, retain) NSArray *feedObjects;
@property (nonatomic, retain) MMPopLabel *noItemsPopLabel;
@property (nonatomic, retain) NSTimer *refreshTimer;
@property (nonatomic, retain) NSMutableDictionary *cellTemplatesByIdentifier;
@property (nonatomic, retain) DFNoTableItemsView *noItemsView;
@property (nonatomic, retain) NSMutableDictionary *cellHeightsByIdentifier;

@end

@implementation DFInboxViewController


- (instancetype)init
{
  self = [super init];
  if (self) {
    _cellTemplatesByIdentifier = [NSMutableDictionary new];
    [self initTabBarItemAndNav];
    [self observeNotifications];
    self.manager = [DFPeanutFeedDataManager sharedManager];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewInboxDataNotificationName
                                             object:nil];
}

- (void)initTabBarItemAndNav
{
  self.navigationItem.title = @"Photos";
  self.tabBarItem.title = @"Photos";
  self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/FeedBarButtonSelected"]
                                   imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/FeedBarButton"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                           initWithTitle:@""
                                           style:UIBarButtonItemStylePlain
                                           target:nil
                                           action:nil];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                            target:self
                                            action:@selector(createButtonPressed:)];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self configureRefreshControl];
  [self configureTableView];
  [self configurePopLabel];
  [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self refreshFromServer];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (![self.manager hasInboxData] && ![self.manager isRefreshingInbox]) {
    [self.refreshControl beginRefreshing];
    [self refreshFromServer];
  }
  
  // prompt for push notifs in inbox if there are any accepted invites in the inbox
  for (DFPeanutFeedObject *object in self.feedObjects) {
    if ([object.type isEqual:DFFeedObjectStrandPosts]) {
      [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
      break;
    }
  }
  
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [self.noItemsPopLabel dismiss];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)configureRefreshControl
{
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
}

- (void)configureTableView
{
  self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
  [self.tableView
   registerNib:[UINib nibWithNibName:@"DFCardTableViewCell" bundle:nil]
   forCellReuseIdentifier:@"inviteCell"];
  [self.tableView
   registerNib:[UINib nibWithNibName:[[DFCardTableViewCell class] description] bundle:nil]
   forCellReuseIdentifier:@"strandCell"];
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"unknown"];
}

- (void)configurePopLabel
{
  self.noItemsPopLabel = [MMPopLabel
                          popLabelWithText:@"Tap here to swap photos"];
  [self.tabBarController.view addSubview:self.noItemsPopLabel];
  
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Data Fetch

- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    _feedObjects = [self.manager acceptedStrands];
    [self.tableView reloadData];
    [self configureNoResultsView];
  });
}

- (void)configureNoResultsView
{
  if (self.feedObjects.count == 0) {
    if (!self.noItemsView) {
      self.noItemsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
      [self.noItemsView setSuperView:self.view];
    }
    
    self.noItemsView.hidden = NO;
    if ([[DFPeanutFeedDataManager sharedManager] hasInboxData]) {
      self.noItemsView.titleLabel.text = @"No Photos Swapped";
      [self.noItemsView.activityIndicator stopAnimating];
      self.noItemsView.subtitleLabel.text = @"Tap the + to get started";
    } else {
      self.noItemsView.titleLabel.text = @"Loading...";
      [self.noItemsView.activityIndicator startAnimating];
      self.noItemsView.subtitleLabel.text = @"";
    }
  } else {
    self.noItemsView.hidden = YES;
  }
}

- (void)refreshFromServer
{
  [self.manager refreshInboxFromServer:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.refreshControl endRefreshing];
    });
  }];
}

- (void)showCreateBalloon
{
  //create a view over the top portion of the create tab
  CGFloat dummyWidth = self.tabBarController.tabBar.frame.size.width / 3.0;
  CGFloat dummyHeight = self.tabBarController.tabBar.frame.size.height / 2.0;
  UIView *dummyView = [[UIView alloc]
                       initWithFrame:
                       CGRectMake(CGRectGetMidX(self.tabBarController.view.frame) - dummyWidth / 2.0,
                                  CGRectGetMaxY(self.tabBarController.view.frame) -
                                  self.tabBarController.tabBar.frame.size.height,
                                  dummyWidth,
                                  dummyHeight)];
  dummyView.backgroundColor = [UIColor clearColor];
  [self.tabBarController.view insertSubview:dummyView belowSubview:self.tabBarController.tabBar];
  [self.noItemsPopLabel popAtView:dummyView animatePopLabel:YES animateTargetView:NO];
  [dummyView removeFromSuperview];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.feedObjects.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  NSString *cellIdentifier = @"inviteCell";
  DFCardCellStyle style = DFCardCellStyleSuggestionWithPeople;
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cellIdentifier = @"inviteCell";
    style = DFCardCellStyleInvite;
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]){
    style = DFCardCellStyleShared;
    cellIdentifier = @"strandCell";
  }

  NSNumber *cachedHeight = self.cellHeightsByIdentifier[cellIdentifier];
  if (!cachedHeight) {
    DFCardTableViewCell *templateCell = [DFCardTableViewCell cellWithStyle:style];
    CGFloat height = [templateCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    self.cellHeightsByIdentifier[cellIdentifier] = cachedHeight = @(height);
  }
  return cachedHeight.floatValue;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    cell = [self cellForInviteObject:feedObject];
  } else if ([feedObject.type isEqual:DFFeedObjectStrandPosts]){
    cell = [self cellForStrandObject:feedObject];
  }
  
  if (!cell) [NSException raise:@"Cell nil" format:@""];
  
  return cell;
}


- (UITableViewCell *)cellForInviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFCardTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"inviteCell"];
  [cell configureWithStyle:DFCardCellStyleInvite];
  
  [cell configureWithFeedObject:inviteObject];
  return cell;
}

- (UITableViewCell *)cellForStrandObject:(DFPeanutFeedObject *)strandObject
{
  DFCardTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"strandCell"];
  [cell configureWithStyle:DFCardCellStyleShared];
  
  [cell configureWithFeedObject:strandObject];
  return cell;
}

+ (void)resetCell:(DFInboxTableViewCell *)cell
{
  cell.timeLabel.text = @"T";
  cell.actorLabel.text = @"Actor";
  cell.actionTextLabel.text = @"Action";
  cell.titleLabel.text = @"Subtitle";
  cell.peopleLabel.text = @"People";
  cell.objects = @[];
}


#pragma mark - Table View delegate

- (void)createButtonPressed:(id)sender
{
  DFCreateStrandFlowViewController *createController = [[DFCreateStrandFlowViewController alloc] init];
  [self presentViewController:createController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  
  DFFeedViewController *feedViewController = [[DFFeedViewController alloc] initWithFeedObject:feedObject];
  [self.navigationController pushViewController:feedViewController animated:YES];
}

- (void)showStrandPostsForStrandID:(DFStrandIDType)strandID completion:(void(^)(void))completion
{
  DDLogInfo(@"%@ showStrandPostsForStrandID called for %@ requesting refresh", self.class, @(strandID));
  [self.manager refreshInboxFromServer:^{
    DDLogInfo(@"%@ showStrandPostsForStrandID for %@ refresh callback", self.class, @(strandID));
    DFPeanutFeedObject *strandPostsObject;
    _feedObjects = [self.manager publicStrands];
    for (DFPeanutFeedObject *object in self.feedObjects) {
      if (object.id == strandID) {
        // the strand is still in the invites section, return
        if ([object.type isEqual:DFFeedObjectStrandPosts]) {
          strandPostsObject = object;
          break;
        } else {
          DDLogError(@"%@ showStrandPostsForStrandID: object.type = %@", self.class, object.type);
        }
      }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (strandPostsObject) {
        DDLogInfo(@"%@ showing strand posts with id%lu",
                  self.class,
                  (long)strandID);
        DFStrandGalleryViewController *vc = [[DFStrandGalleryViewController alloc] init];
        vc.strandPosts = strandPostsObject;
        [self.navigationController setViewControllers:@[self, vc] animated:YES];
        
      } else {
        [self.navigationController setViewControllers:@[self]];
        DDLogError(@"%@ got a request to show strand with id:%lu but none loaded with that ID",
                   self.class,
                   (long)strandID);
      }
      completion();
    });
  }];
}


@end
