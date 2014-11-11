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
#import "DFNotificationsViewController.h"
#import "DFFeedSectionHeaderView.h"
#import "DFPeanutFeedObject.h"
#import "DFSelectPhotosViewController.h"


@interface DFFeedViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate,
DFPhotoFeedCellDelegate, DFFeedSectionHeaderViewDelegate, DFSelectPhotosViewControllerDelegate>

@property (nonatomic) DFPhotoIDType onViewScrollToPhotoId;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
- (instancetype)initWithFeedObject:(DFPeanutFeedObject *)feedObject;

/* 
 Use this to present a feed view controller modally for a given feed object, for example
 when responding to a tap on a push notification
 */
+ (DFFeedViewController *)presentFeedObject:(DFPeanutFeedObject *)feedObject
  modallyInViewController:(UIViewController *)viewController;

@end
