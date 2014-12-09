//
//  DFHomeViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFFriendsViewController.h"

@interface DFHomeViewController : DFFriendsViewController
@property (weak, nonatomic) IBOutlet UIButton *reviewButton;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
- (IBAction)reviewButtonPressed:(id)sender;
- (IBAction)sendButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end
