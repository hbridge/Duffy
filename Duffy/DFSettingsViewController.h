//
//  DFSettingsViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFSettingsViewController : UIViewController
    <UITableViewDataSource, UITableViewDelegate>

extern NSString *DFPipelineEnabledUserDefaultKey;
extern NSString *DFPipelineEnabledYes;
extern NSString *DFPipelineEnabledNo;

@property (weak, nonatomic) IBOutlet UITableView *settingsTableView;


- (IBAction)pipelineEnabledSwitchChanged:(id)sender;

@end
