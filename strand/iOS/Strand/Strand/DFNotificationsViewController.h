//
//  DFNotificationsViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFNotificationsViewController;

@protocol DFNotificationsViewControllerDelegate <NSObject>

@required
- (void)notificationViewController:(DFNotificationsViewController *)notificationViewController
  didSelectNotificationWithPhotoID:(DFPhotoIDType)photoID;

@end

@interface DFNotificationsViewController : UITableViewController

@property (nonatomic, retain) id<DFNotificationsViewControllerDelegate> delegate;

@end
