//
//  DFNotificationsViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNotificationsViewController.h"
#import "DFPeanutNotificationsManager.h"
#import "DFPeanutNotification.h"
#import "DFNotificationTableViewCell.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFImageManager.h"
#import "DFAnalytics.h"

@interface DFNotificationsViewController ()

@property (nonatomic, retain) NSArray *unreadNotifications;
@property (nonatomic, retain) NSArray *readNotifications;

@end

@implementation DFNotificationsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  if (self) {
    self.navigationItem.title = @"Notifications";
    self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/NotificationsBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/NotificationsBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNotificationTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"cell"];
  self.tableView.separatorInset = UIEdgeInsetsMake(0, 50, 0, 0);
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  self.unreadNotifications = [[DFPeanutNotificationsManager sharedManager] unreadNotifications];
  self.readNotifications = [[DFPeanutNotificationsManager sharedManager] readNotifications];
  [self.tableView reloadData];
  
  [[DFPeanutNotificationsManager sharedManager] markNotificationsAsRead];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
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

- (DFPeanutNotification *)peanutNotificationForIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutNotification *peanutNotification;
  if (indexPath.row < self.unreadNotifications.count) {
    peanutNotification = self.unreadNotifications[indexPath.row];
  } else {
    peanutNotification = self.readNotifications[indexPath.row - self.unreadNotifications.count];
  }

  return peanutNotification;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFNotificationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
  
  DFPeanutNotification *peanutNotification = [self peanutNotificationForIndexPath:indexPath];
  
  // set cell basic data
  cell.nameLabel.text = peanutNotification.actor_display_name;
  cell.descriptionLabel.text = peanutNotification.action_text;
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:peanutNotification.time
                         abbreviate:YES];
  
  //set the preview image
  cell.previewImageView.image = nil;
  [[DFImageManager sharedManager]
   imageForID:peanutNotification.photo_id.longLongValue
   preferredType:DFImageThumbnail
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![tableView.visibleCells containsObject:cell]) return;
       cell.previewImageView.image = image;
     });
   }];
  
  //decide whether to highlight
  if (indexPath.row < self.unreadNotifications.count) {
    cell.backgroundColor = [UIColor colorWithRed:229/255.0 green:239/255.0 blue:251/255.0 alpha:1.0];
  }
  
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutNotification *notification = [self peanutNotificationForIndexPath:indexPath];
  DDLogVerbose(@"%@ notif tapped for notif:%@", [self.class description], notification);
  [DFAnalytics logNotificationViewItemOpened:notification.action_text notifDate:notification.time];
  
  if (self.delegate) {
    [self.delegate notificationViewController:self
             didSelectNotificationWithPhotoID:notification.photo_id.longLongValue];
  }
}



@end
