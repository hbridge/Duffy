//
//  DFSettingsViewController.h
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "DFKeyboardResizingViewController.h"

@interface DFSettingsViewController : DFKeyboardResizingViewController <UITextFieldDelegate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate>

- (IBAction)scrollViewTapped:(UITapGestureRecognizer *)sender;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UILabel *appInfoLabel;

// User section outlets
@property (weak, nonatomic) IBOutlet UITextField *userIDTextField;

//Upload section outlets
@property (weak, nonatomic) IBOutlet UISwitch *autoUploadEnabledSwitch;

// Upload section actions
- (IBAction)autoUploadEnabledSwitchChanged:(UISwitch *)sender;
- (IBAction)cancelUpload:(UIButton *)sender;

- (IBAction)sendInfoClicked:(UIButton *)sender;
- (IBAction)developerSettingsClicked:(UIButton *)sender;


@end
