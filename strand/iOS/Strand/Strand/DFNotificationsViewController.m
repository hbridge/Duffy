//
//  DFNotificationsViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNotificationsViewController.h"
#import "DFPeanutNotificationsManager.h"
#import "DFPeanutAction.h"
#import "DFNotificationTableViewCell.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFImageManager.h"
#import "DFAnalytics.h"
#import <Slash/Slash.h>
#import "DFPeanutFeedDataManager.h"
#import "NSIndexPath+DFHelpers.h"
#import "DFPhotoDetailViewController.h"
#import "DFDismissableModalViewController.h"
#import <WYPopoverController/WYPopoverController.h>
#import "DFNoTableItemsView.h"
#import "DFUserInfoManager.h"

@interface DFNotificationsViewController ()

@property (nonatomic, retain) DFNotificationTableViewCell *templateCell;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) NSMutableDictionary *rowHeightCache;
@property (nonatomic, retain) DFNoTableItemsView *noResultsView;

@end

@implementation DFNotificationsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  if (self) {
    self.navigationItem.title = @"Notifications";
    self.tabBarItem.title = @"Notifications";
    self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/NotificationsBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/NotificationsBarButtonSelected"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.templateCell = [DFNotificationTableViewCell templateCell];

    self.rowHeightCache = [NSMutableDictionary new];
    [self observeNotifications];
    [self reloadData];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNotificationTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"cell"];
  self.tableView.separatorInset = UIEdgeInsetsMake(0, 15, 0, 15);
  self.tableView.rowHeight = 56.0;
  [self configureRefreshControl];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadData];
  [self.refreshControl endRefreshing];
  [self refreshFromServer];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  [DFAnalytics
   logViewController:self
   appearedWithParameters:
   @{
     @"unreadNotifs" : [DFAnalytics bucketStringForObjectCount:[[DFPeanutNotificationsManager sharedManager] unreadNotifications].count],
     @"readNotifs" : [DFAnalytics bucketStringForObjectCount:[[DFPeanutNotificationsManager sharedManager] readNotifications].count],
     @"badgeValue" : [DFAnalytics bucketStringForObjectCount:self.tabBarItem.badgeValue.integerValue]
     }];
  self.tabBarItem.badgeValue = nil;
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [[DFUserInfoManager sharedManager] setLastNotifsOpenedTimestamp:[NSDate date]];
  [[DFPeanutNotificationsManager sharedManager] markAllNotificationsAsRead];
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNotificationsUpdatedNotification
                                             object:nil];
}


- (void)configureRefreshControl
{
  self.refreshControl = [[UIRefreshControl alloc] init];
  
  [self.refreshControl addTarget:self
                          action:@selector(refreshFromServer)
                forControlEvents:UIControlEventValueChanged];
}

- (void)reloadData
{
  self.rowHeightCache = [NSMutableDictionary new];
  if ([[[DFPeanutNotificationsManager sharedManager] notifications] count] > 0) {
    [self.tableView reloadData];
    [self setNoResultsViewHidden:YES];
  } else {
    [self setNoResultsViewHidden:NO];
  }
}

- (void)setNoResultsViewHidden:(BOOL)hidden
{
  if (hidden) {
    [self.noResultsView removeFromSuperview];
    self.noResultsView = nil;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
  } else if (!self.noResultsView) {
    self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
    self.noResultsView.titleLabel.text = @"No Notifications";
    self.noResultsView.subtitleLabel.text = @"New photos, comments and likes will appear here.";
    [self.noResultsView setSuperView:self.view];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  }
}

- (void)refreshFromServer
{
  [[DFPeanutFeedDataManager sharedManager] refreshFeedFromServer:DFActionsFeed completion:^{
    [self.refreshControl endRefreshing];
  }];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [[[DFPeanutNotificationsManager sharedManager] notifications] count];
}

- (DFPeanutAction *)peanutActionForIndexPath:(NSIndexPath *)indexPath
{
  return [[[DFPeanutNotificationsManager sharedManager] notifications] objectAtIndex:indexPath.row];
}

- (NSAttributedString *)attributedStringForAction:(DFPeanutAction *)action
{
  NSString *actionString;
  if (action.action_type == DFPeanutActionFavorite) {
    actionString = @"liked a photo.";
  } else if (action.action_type == DFPeanutActionComment) {
    actionString = @"commented: ";
  } else if (action.action_type == DFPeanutActionAddedPhotos) {
    actionString = action.text;
  }

  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:action.user];
  NSString *markup =
  [NSString stringWithFormat:@"<name>%@</name> %@%@ <gray>%@</gray>",
   [user firstName],
   actionString,
   action.action_type == DFPeanutActionComment ? [action.text stringByEscapingCharsInString:@"<>"] : @"",
   [NSDateFormatter relativeTimeStringSinceDate:action.time_stamp abbreviate:YES]
   ];
  
  
  NSError *parseError;
  NSAttributedString *attributedString = [SLSMarkupParser
                                     attributedStringWithMarkup:markup
                                     style:[DFStrandConstants defaultTextStyle]
                                     error:&parseError];
  if (parseError) DDLogError(@"%@ parse error:%@", self.class, parseError);
  return attributedString;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFNotificationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
  
  DFPeanutAction *action = [self peanutActionForIndexPath:indexPath];
  
  // set cell basic data
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:action.user];
  [cell.profilePhotoStackView setPeanutUser:user];
  cell.detailLabel.attributedText = [self attributedStringForAction:action];
  
  //set the preview image
  cell.previewImageView.image = nil;
  if (action.photo > 0) {
    [[DFImageManager sharedManager]
     imageForID:action.photo.longLongValue
     pointSize:cell.previewImageView.frame.size
     contentMode:DFImageRequestContentModeAspectFill
     deliveryMode:DFImageRequestOptionsDeliveryModeFastFormat
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         if (![tableView.visibleCells containsObject:cell]) return;
         cell.previewImageView.image = image;
       });
     }];
  }
  
  //decide whether to highlight
  if ([[DFPeanutNotificationsManager sharedManager] isActionIDSeen:action.id.longLongValue]) {
    cell.backgroundColor = [UIColor whiteColor];
  } else {
    cell.backgroundColor = [DFStrandConstants unreadNotificationBackgroundColor];
  }
  
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSNumber *cachedHeight = self.rowHeightCache[[indexPath dictKey]];
  if (cachedHeight) return cachedHeight.floatValue;
  
  DFPeanutAction *action = [self peanutActionForIndexPath:indexPath];
  self.templateCell.detailLabel.attributedText = [self attributedStringForAction:action];
  CGFloat rowHeight = self.templateCell.rowHeight;
  self.rowHeightCache[[indexPath dictKey]] = @(rowHeight);
  return rowHeight;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return 57;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutAction *action = [self peanutActionForIndexPath:indexPath];
  [DFAnalytics logNotificationViewItemOpened:[DFAnalytics actionStringForType:action.action_type]
                                   notifDate:action.time_stamp];
  [self.delegate notificationViewController:self didSelectNotificationWithAction:action];
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
