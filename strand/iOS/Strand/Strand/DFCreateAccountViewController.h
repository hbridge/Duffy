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
@property (weak, nonatomic) IBOutlet UILabel *countryCodeLabel;
@property (weak, nonatomic) IBOutlet UITextField *phoneNumberField;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UIButton *termsButton;
@property (nonatomic, retain) UIBarButtonItem *doneBarButtonItem;

- (IBAction)countryCodeTapped:(UITapGestureRecognizer *)sender;
- (IBAction)phoneFieldTapped:(id)sender;
- (IBAction)phoneNumberFieldValueChanged:(UITextField *)sender;
- (IBAction)nameTextFieldChanged:(UITextField *)sender;
- (IBAction)termsButtonPressed:(id)sender;



@end
