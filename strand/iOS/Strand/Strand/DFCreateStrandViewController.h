//
//  DFCreateStrandViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MCSwipeTableViewCell/MCSwipeTableViewCell.h>

@interface DFCreateStrandViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, MCSwipeTableViewCellDelegate>

@property (nonatomic) BOOL showAsFirstTimeSetup;
@property (nonatomic, retain) IBOutlet UITableView *suggestedTableView;
@property (nonatomic, retain) IBOutlet UITableView *allTableView;
@property (nonatomic, retain) NSArray *refreshControls;
@property (readonly, nonatomic, retain) UIRefreshControl *refreshControl;
@property (weak, nonatomic) IBOutlet UIView *reloadBackground;
- (IBAction)reloadButtonPressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIView *segmentWrapper;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
- (IBAction)segmentedControlValueChanged:(id)sender;

+ (instancetype)sharedViewController;
- (void)refreshFromServer;

@end
