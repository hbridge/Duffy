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
#import "DFImageStore.h"

@interface DFNotificationsViewController ()

@property (nonatomic, retain) NSArray *peanutNotifications;

@end

@implementation DFNotificationsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  if (self) {
    // Custom initialization
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
  self.peanutNotifications = [[DFPeanutNotificationsManager sharedManager] notifications];
  [self.tableView reloadData];
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
  return self.peanutNotifications.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return @"Notifications";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFNotificationTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
  
  DFPeanutNotification *peanutNotification = self.peanutNotifications[indexPath.row];
  cell.nameLabel.text = peanutNotification.actor_display_name;
  cell.descriptionLabel.text = peanutNotification.action_text;
  cell.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:peanutNotification.time];
  cell.previewImageView.image = nil;
  [[DFImageStore sharedStore]
   imageForID:peanutNotification.photo_id.longLongValue
   preferredType:DFImageThumbnail
   thumbnailPath:peanutNotification.photo_thumb_path
   fullPath:nil
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![tableView.visibleCells containsObject:cell]) return;
       cell.previewImageView.image = image;
     });
   }];
  
  return cell;
}



@end
