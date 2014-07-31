//
//  DFSMSCodeEntryViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFSMSCodeEntryViewController : UIViewController <UITextFieldDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UITextField *codeTextField;
@property (nonatomic, retain) NSString *phoneNumberString;
@property (nonatomic, retain) NSString *userName;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
- (IBAction)doneButtonPressed:(id)sender;

@end
