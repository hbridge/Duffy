//
//  DFSMSCodeEntryViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSMSCodeEntryViewController.h"
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "AppDelegate.h"

@interface DFSMSCodeEntryViewController ()

@end

@implementation DFSMSCodeEntryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
  self.codeTextField.delegate = self;
  [self.codeTextField becomeFirstResponder];
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                            target:self
                                            action:@selector(doneButtonPressed:)];
  
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
  [self setCodeTextFieldCursorOffset:0];
}

- (void)setCodeTextFieldCursorOffset:(NSUInteger)offset
{
  UITextPosition *position = [self.codeTextField
                              positionFromPosition:self.codeTextField.beginningOfDocument
                              offset:offset];
  self.codeTextField.selectedTextRange = [self.codeTextField textRangeFromPosition:position
                                                                        toPosition:position];
  
}

- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
  // if there are no dashes left, don't allow a change
  if (![string isEqualToString:@""] && [textField.text rangeOfString:@"-"].location == NSNotFound) {
    return NO;
  }
  
  // if the user typed a char, remove the first '-' or " -"
  if (![string isEqualToString:@""]) {
    textField.text = [textField.text
                      stringByReplacingCharactersInRange:(NSRange){range.location,
                        MIN(2, textField.text.length - range.location)}
                      withString:[NSString stringWithFormat:@"%@ ", string]];
    textField.text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  
    NSRange firstDashRange = [textField.text
                                 rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"-"]];
    if (firstDashRange.location != NSNotFound) {
      [self setCodeTextFieldCursorOffset:firstDashRange.location];
    } else {
      [self setCodeTextFieldCursorOffset:self.codeTextField.text.length];
    }
    
    return NO;
  }
  
  // if the deleted a char, replace it with a " -"
  if ([string isEqualToString:@""]) {
    NSRange replaceRange;
    if (range.location < textField.text.length - 1) {
      replaceRange = (NSRange){MAX(0, range.location - 1), 2};
      textField.text = [textField.text stringByReplacingCharactersInRange:replaceRange withString:@"- "];
    } else {
      replaceRange = (NSRange){range.location, 1};
      textField.text = [textField.text stringByReplacingCharactersInRange:replaceRange withString:@"-"];
    }
    [self setCodeTextFieldCursorOffset:replaceRange.location];
    return NO;
  }
  
  
  return YES;
}

- (void)doneButtonPressed:(id)sender
{
  NSString *authCode = [self.codeTextField.text stringByReplacingOccurrencesOfString:@" "
                                                                          withString:@""];
  DDLogInfo(@"User entered auth code: %@", authCode);
}


- (void)getUserIDWithPhoneNumber:(NSString *)phoneNumberString
                        authCode:(NSString *)authCodeString
{
  DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
  
  [userAdapter createUserForDeviceID:[[DFUser currentUser] deviceID]
                          deviceName:[[DFUser currentUser] deviceName]
                         phoneNumber:phoneNumberString
                       smsAuthString:authCodeString
                    withSuccessBlock:^(DFUser *user) {
                      [[DFUser currentUser] setUserID:user.userID];
                      AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
                      [delegate showMainView];
                    }
                        failureBlock:^(NSError *error) {
                          DDLogWarn(@"Create user failed: %@", error.localizedDescription);
                          UIAlertView *failureAlert = [DFSMSCodeEntryViewController accountFailedAlert:error];
                          [failureAlert show];
                        }];

}


+ (UIAlertView *)accountFailedAlert:(NSError *)error
{
  return [[UIAlertView alloc] initWithTitle:@"Couldn't Create Account"
                                    message:[NSString stringWithFormat:@"%@.  Please try again.",
                                             error.localizedDescription]
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil];
}


@end
