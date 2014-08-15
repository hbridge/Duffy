//
//  DFPhotoFeedController.h
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFStrandsViewController.h"
#import "DFPhotoFeedCell.h"
#import "DFNavigationBar.h"
#import "DFTopBarController.h"
#import "WYPopoverController.h"
#import "DFNotificationsViewController.h"

@interface DFPhotoFeedController : DFStrandsViewController
<UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate,
DFPhotoFeedCellDelegate, DFStrandViewControllerDelegate>

@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (readonly, nonatomic, retain) DFTopBarController *topBarController;

- (void)jumpToPhoto:(DFPhotoIDType)photoID;

@end
