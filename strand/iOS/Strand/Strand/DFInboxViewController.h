//
//  DFStrandsFeedViewController.h
//  Strand
//
//  Created by Henry Bridge on 9/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DFInboxViewController : UITableViewController

@property (strong, nonatomic) IBOutlet UITableView *tableView;

- (void)showStrandPostsForStrandID:(DFStrandIDType)strandID completion:(void(^)(void))completion;

@end
