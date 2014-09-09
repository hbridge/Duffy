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
#import "DFFeedSectionHeaderView.h"
#import "DFPeanutFeedObject.h"

@interface DFFeedViewController : DFStrandsViewController
<UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate,
DFPhotoFeedCellDelegate, DFStrandViewControllerDelegate, DFFeedSectionHeaderViewDelegate>

@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (nonatomic, retain) DFPeanutFeedObject *strandToShow;

- (void)jumpToPhoto:(DFPhotoIDType)photoID;

@end
