//
//  DFStrandPeopleViewController.h
//  Strand
//
//  Created by Henry Bridge on 11/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"

@interface DFStrandPeopleViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;


//@property (nonatomic, retain) DFPeanutFeedObject *inviteObject;
@property (nonatomic, retain) DFPeanutFeedObject *strandPostsObject;


- (instancetype)initWithStrandPostsObject:(DFPeanutFeedObject *)strandPostsObject;

@end
