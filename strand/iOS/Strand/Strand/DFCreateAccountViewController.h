//
//  DFFirstTimeSetupViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNUXViewController.h"

@interface DFCreateAccountViewController : DFNUXViewController <UITextFieldDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *countryButton;
@property (weak, nonatomic) IBOutlet UIButton *countryCodeButton;
@property (weak, nonatomic) IBOutlet UITextField *phoneNumberField;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UIButton *termsButton;
@property (nonatomic, retain) UIBarButtonItem *doneBarButtonItem;

- (IBAction)phoneFieldTapped:(id)sender;
- (IBAction)phoneNumberFieldValueChanged:(UITextField *)sender;
- (IBAction)nameTextFieldChanged:(UITextField *)sender;
- (IBAction)termsButtonPressed:(id)sender;
- (IBAction)showCountryCodePicker:(id)sender;



@end
