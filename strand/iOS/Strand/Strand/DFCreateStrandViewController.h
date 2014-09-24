//
//  DFCreateStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFCreateStrandViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) BOOL showAsFirstTimeSetup;
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;
@property (weak, nonatomic) IBOutlet UIView *reloadBackground;
- (IBAction)reloadButtonPressed:(id)sender;


+ (instancetype)sharedViewController;
- (void)refreshFromServer;

@end
