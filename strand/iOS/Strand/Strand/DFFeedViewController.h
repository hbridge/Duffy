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

@interface DFFeedViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate,
DFPhotoFeedCellDelegate, DFStrandViewControllerDelegate, DFFeedSectionHeaderViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
- (void)showPhoto:(DFPhotoIDType)photoId animated:(BOOL)animated;
- (instancetype)initWithFeedObject:(DFPeanutFeedObject *)feedObject;

@end
