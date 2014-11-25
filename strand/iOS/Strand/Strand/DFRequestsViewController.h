//
//  DFRequestsViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFRequestsViewController;
@class DFPeanutFeedObject;

@protocol DFRequestsViewControllerActionDelegate <NSObject>

- (void)requestsViewController:(DFRequestsViewController *)requestsViewController
                inviteSelected:(DFPeanutFeedObject *)invite;

@end


@interface DFRequestsViewController : UIPageViewController <UIPageViewControllerDataSource, UIPageViewControllerDelegate>

@property (nonatomic, retain) NSArray *inviteFeedObjects;
@property (nonatomic) CGFloat height;
@property (nonatomic, weak) id<DFRequestsViewControllerActionDelegate> actionDelegate;

@end
