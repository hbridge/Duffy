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

@property (weak, nonatomic) IBOutlet UITableView *tableView;
- (void)showPhoto:(DFPhotoIDType)photoId animated:(BOOL)animated;
- (instancetype)initWithFeedObject:(DFPeanutFeedObject *)feedObject;

/* 
 Use this to present a feed view controller modally for a given feed object, for example
 when responding to a tap on a push notification
 */
+ (void)presentFeedObject:(DFPeanutFeedObject *)feedObject
  modallyInViewController:(UIViewController *)viewController;

@end
