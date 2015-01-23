//
//  DFSMSCodeEntryViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNUXViewController.h"

@interface DFSMSAuthViewController : DFNUXViewController <UITextFieldDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UITextField *codeTextField;
@property (weak, nonatomic) IBOutlet UIView *codeTextFieldOverlay;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
- (IBAction)doneButtonPressed:(id)sender;
- (IBAction)codeTextFieldOverlayPressed:(id)sender;

@end
