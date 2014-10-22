//
//  DFSwapViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFSwapViewController : UIViewController
  <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end
