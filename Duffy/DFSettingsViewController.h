//
//  DFSettingsViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFKeyboardResizingViewController.h"

@interface DFSettingsViewController : DFKeyboardResizingViewController <UITextFieldDelegate>

extern NSString *DFPipelineEnabledUserDefaultKey;
extern NSString *DFAutoUploadEnabledUserDefaultKey;
extern NSString *DFEnabledYes;
extern NSString *DFEnabledNo;

- (IBAction)scrollViewTapped:(UITapGestureRecognizer *)sender;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

// Device/user section outlets
@property (weak, nonatomic) IBOutlet UILabel *deviceIDLabel;
@property (weak, nonatomic) IBOutlet UITextField *userIDTextField;
@property (weak, nonatomic) IBOutlet UITextField *deviceIDTextField;
// Server section outlets
@property (weak, nonatomic) IBOutlet UITextField *serverURLTextField;
@property (weak, nonatomic) IBOutlet UITextField *serverPortTextField;
//Upload section outlets
@property (weak, nonatomic) IBOutlet UISwitch *autoUploadEnabledSwitch;
@property (weak, nonatomic) IBOutlet UILabel *numUploadedLabel;
@property (weak, nonatomic) IBOutlet UILabel *numToUploadLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *uploadProgressView;

// Device/user section actions
- (IBAction)deviceIDEditingDidEnd:(UITextField *)sender;
- (IBAction)userIDEditingDidEnd:(UITextField *)sender;
- (IBAction)copyDeviceIDClicked:(UIButton *)sender;
// Server section actions
- (IBAction)serverURLEditingDidEnd:(UITextField *)sender;


// Upload section actions
- (IBAction)reUploadAllClicked:(UIButton *)sender;
- (IBAction)autoUploadEnabledSwitchChanged:(UISwitch *)sender;
- (IBAction)serverPortEditingDidEnd:(UITextField *)sender;


@end
