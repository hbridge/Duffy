//
//  DFStrandsFeedViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandsViewController.h"

@interface DFActivityFeedViewController : DFStrandsViewController <UITableViewDataSource, UITableViewDelegate, DFStrandViewControllerDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
