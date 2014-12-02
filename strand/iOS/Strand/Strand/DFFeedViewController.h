//
//  DFPhotoFeedController.h
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFNavigationBar.h"
#import "DFNotificationsViewController.h"
#import "DFFeedSectionHeaderView.h"
#import "DFPeanutFeedObject.h"
#import "DFSelectPhotosViewController.h"
#import "DFFeedDataSource.h"



@interface DFFeedViewController : UIViewController
<DFFeedDataSourceDelegate, DFSelectPhotosViewControllerDelegate, UIActionSheetDelegate>

@property (nonatomic) DFPhotoIDType onViewScrollToPhotoId;
@property (nonatomic) BOOL showPersonPerPhoto;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
- (instancetype)initWithFeedObject:(DFPeanutFeedObject *)feedObject;
- (instancetype)initWithStrandPostsId:(DFStrandIDType)strandID;

/* 
 Use this to present a feed view controller modally for a given feed object, for example
 when responding to a tap on a push notification
 */
+ (DFFeedViewController *)presentFeedObject:(DFPeanutFeedObject *)postsObject
  modallyInViewController:(UIViewController *)viewController;

@end
