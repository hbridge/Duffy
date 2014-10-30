//
//  DFSwapViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutUserObject.h"

@interface DFSwapViewController : UIViewController
  <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) DFPeanutUserObject *userToFilter;

- (instancetype)initWithUserToFilter:(DFPeanutUserObject *)user;

@end
