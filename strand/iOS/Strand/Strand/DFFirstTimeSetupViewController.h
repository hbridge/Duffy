//
//  DFFirstTimeSetupViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFFirstTimeSetupViewController : UIViewController <UITextFieldDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *phoneNumberField;
@property (nonatomic, retain) UIBarButtonItem *doneBarButtonItem;
@property (weak, nonatomic) IBOutlet UIButton *termsButton;
- (IBAction)phoneNumberFieldValueChanged:(UITextField *)sender;
- (IBAction)termsButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
- (IBAction)nameTextFieldChanged:(UITextField *)sender;

@end
