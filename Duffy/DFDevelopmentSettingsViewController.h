//
//  DFDevelopmentSettingsViewController.h
//  Duffy
//
//  Created by Henry Bridge on 5/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFKeyboardResizingViewController.h"


@interface DFDevelopmentSettingsViewController : DFKeyboardResizingViewController <UITextFieldDelegate,
UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

// Device/user section outlets
@property (weak, nonatomic) IBOutlet UILabel *deviceIDLabel;
@property (weak, nonatomic) IBOutlet UITextField *deviceIDTextField;

// Server section outlets
@property (weak, nonatomic) IBOutlet UITextField *serverURLTextField;
@property (weak, nonatomic) IBOutlet UITextField *serverPortTextField;

// Device/user section actions
- (IBAction)deviceIDEditingDidEnd:(UITextField *)sender;
- (IBAction)copyDeviceIDClicked:(UIButton *)sender;

- (IBAction)scrollViewTapped:(UITapGestureRecognizer *)sender;

// Server section actions
- (IBAction)serverURLEditingDidEnd:(UITextField *)sender;
- (IBAction)serverPortEditingDidEnd:(UITextField *)sender;

// Upload section actions
- (IBAction)clearUploadDatabaseClicked:(UIButton *)sender;

// Other
- (IBAction)crashAppClicked:(UIButton *)sender;


@end
