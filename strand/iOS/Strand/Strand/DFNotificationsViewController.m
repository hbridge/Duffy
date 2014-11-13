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
#import "DFFeedViewController.h"
#import "DFPeanutFeedDataManager.h"

@interface DFNotificationsViewController ()

@property (nonatomic, retain) NSArray *unreadNotifications;
@property (nonatomic, retain) NSArray *readNotifications;
@property (nonatomic, retain) DFNotificationTableViewCell *templateCell;

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
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  [DFAnalytics
   logViewController:self
   appearedWithParameters:
   @{
     @"unreadNotifs" : [DFAnalytics bucketStringForObjectCount:self.unreadNotifications.count],
     @"readNotifs" : [DFAnalytics bucketStringForObjectCount:self.readNotifications.count],
     @"badgeValue" : [DFAnalytics bucketStringForObjectCount:self.tabBarItem.badgeValue.integerValue]
     }];
  self.tabBarItem.badgeValue = nil;
  [[DFPeanutNotificationsManager sharedManager] markNotificationsAsRead];
  
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNotificationsUpdatedNotification
                                             object:nil];
}

- (void)reloadData
{
  self.unreadNotifications = [[DFPeanutNotificationsManager sharedManager] unreadNotifications];
  self.readNotifications = [[DFPeanutNotificationsManager sharedManager] readNotifications];
  [self.tableView reloadData];
  
  if (self.unreadNotifications.count == 0) {
    self.tabBarItem.badgeValue = nil;
  } else {
    self.tabBarItem.badgeValue = [@(self.unreadNotifications.count) stringValue];
  }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return self.unreadNotifications.count + self.readNotifications.count;
}

- (DFPeanutAction *)peanutActionForIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutAction *peanutAction;
  if (indexPath.row < self.unreadNotifications.count) {
    peanutAction = self.unreadNotifications[indexPath.row];
  } else {
    peanutAction = self.readNotifications[indexPath.row - self.unreadNotifications.count];
  }

  return peanutAction;
}

- (NSAttributedString *)attributedStringForAction:(DFPeanutAction *)action
{
  NSString *markup =
  [NSString stringWithFormat:@"<name>%@</name> %@%@ <gray>%@ ago</gray>",
   [action firstNameOrYou],
   action.action_type == DFPeanutActionFavorite ? @"liked a photo." : @"commented: ",
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
  DFPeanutUserObject *peanutUser = [[DFPeanutUserObject alloc] init];
  peanutUser.id = action.user;
  peanutUser.display_name = action.user_display_name;
  cell.profilePhotoStackView.peanutUsers = @[peanutUser];
  cell.detailLabel.attributedText = [self attributedStringForAction:action];
  
  //set the preview image
  cell.previewImageView.image = nil;
  if (action.photo > 0) {
    [[DFImageManager sharedManager]
     imageForID:action.photo
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
  if (indexPath.row < self.unreadNotifications.count) {
    cell.backgroundColor = [UIColor colorWithRed:229/255.0 green:239/255.0 blue:251/255.0 alpha:1.0];
  } else {
    cell.backgroundColor = [UIColor whiteColor];
  }
  
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutAction *action = [self peanutActionForIndexPath:indexPath];
  self.templateCell.detailLabel.attributedText = [self attributedStringForAction:action];
  return self.templateCell.rowHeight;
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
  
  DFPeanutFeedObject *strandPostsObject = [[DFPeanutFeedDataManager sharedManager]
                                           strandPostsObjectWithId:action.strand];
  DFFeedViewController *fvc = [DFFeedViewController
                               presentFeedObject:strandPostsObject
                               modallyInViewController:self];
  fvc.onViewScrollToPhotoId = action.photo;
}

@end
