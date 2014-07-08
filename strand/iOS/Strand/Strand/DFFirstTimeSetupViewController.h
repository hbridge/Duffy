//
//  DFFirstTimeSetupViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFFirstTimeSetupViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *phoneNumberField;
@property (nonatomic, retain) UIBarButtonItem *doneBarButtonItem;
- (IBAction)phoneNumberFieldValueChanged:(UITextField *)sender;

@end
