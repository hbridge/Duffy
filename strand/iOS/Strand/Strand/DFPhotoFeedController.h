//
//  DFPhotoFeedController.h
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPhotoFeedCell.h"
#import "DFNavigationBar.h"
#import "DFTopBarController.h"
#import "WYPopoverController.h"
#import "DFNotificationsViewController.h"

@interface DFPhotoFeedController : DFTopBarController
<UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate,
DFPhotoFeedCellDelegate, WYPopoverControllerDelegate, DFNotificationsViewControllerDelegate>

@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;

- (IBAction)cameraButtonPressed:(id)sender;
- (IBAction)inviteButtonPressed:(id)sender;
- (void)jumpToPhoto:(DFPhotoIDType)photoID;

@end
