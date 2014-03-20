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
extern NSString *DFAutoUploadEnabledUserDefaultKey;
extern NSString *DFEnabledYes;
extern NSString *DFEnabledNo;

@property (weak, nonatomic) IBOutlet UILabel *deviceIDLabel;
@property (weak, nonatomic) IBOutlet UISwitch *pipelineEnabledSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *autoUploadEnabledSwitch;

- (IBAction)copyDeviceIDClicked:(UIButton *)sender;
- (IBAction)reUploadAllClicked:(UIButton *)sender;
- (IBAction)pipelineEnabledSwitchChanged:(UISwitch *)sender;
- (IBAction)autoUploadEnabledSwitchChanged:(UISwitch *)sender;

@end
