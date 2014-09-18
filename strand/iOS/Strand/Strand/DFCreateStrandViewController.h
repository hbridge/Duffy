//
//  DFCreateStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFCreateStrandViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) BOOL showAsFirstTimeSetup;

+ (instancetype)sharedViewController;
- (void)refreshFromServer;

@end
