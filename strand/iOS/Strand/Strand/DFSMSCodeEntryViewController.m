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
#import "NSString+DFHelpers.h"
#import "DFModalSpinnerViewController.h"
#import "DFAnalytics.h"

const UInt16 DFCodeLength = 4;

@interface DFSMSCodeEntryViewController ()

@end

@implementation DFSMSCodeEntryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
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

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPhoneNumberString:(NSString *)phoneNumberString
{
  _phoneNumberString = phoneNumberString;
  self.navigationItem.title = [NSString stringWithFormat:@"Verify %@", phoneNumberString];
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
  if (![self isEnteredCodeValid]) {
    [self showInvalidCodeAlert:[self enteredCode]];
    [DFAnalytics logSetupSMSCodeEnteredWithResult:DFAnalyticsValueResultInvalidInput];
    return;
  }
  NSString *authCode = [self enteredCode];
  [self getUserIDWithPhoneNumber:self.phoneNumberString authCode:authCode];
  DDLogInfo(@"User entered auth code: %@", authCode);
}

- (NSString *)enteredCode
{
  NSMutableString *mutableCode = self.codeTextField.text.mutableCopy;
  [mutableCode replaceOccurrencesOfString:@" " withString:@"" options:0 range:mutableCode.fullRange];
  [mutableCode replaceOccurrencesOfString:@"-" withString:@"" options:0 range:mutableCode.fullRange];
  return mutableCode;
}


- (BOOL)isEnteredCodeValid
{
  NSError *error;
  NSRegularExpression *regex = [[NSRegularExpression alloc]
                                initWithPattern:[NSString stringWithFormat:@"\\d{%d}",DFCodeLength]
                                options:0
                                error:&error];
  if (error) {
    [NSException raise:@"Invalid Regex" format:@"Error: %@", error.description];
  }
  
  return [regex numberOfMatchesInString:[self enteredCode]
                                options:0
                                  range:(NSRange){0, [[self enteredCode] length]}
          ] == 1;
}

- (void)showInvalidCodeAlert:(NSString *)code
{
  UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:@"Invalid Code"
                        message:[NSString stringWithFormat:@"'%@' is an invalid code."
                                 " Please enter the %d digit code you were sent"
                                 " or press back to request a new one.", code, DFCodeLength]
                        delegate:nil
                        cancelButtonTitle:@"OK"
                        otherButtonTitles:nil];
  [alert show];
}

- (void)getUserIDWithPhoneNumber:(NSString *)phoneNumberString
                        authCode:(NSString *)authCodeString
{
  DFModalSpinnerViewController *msvc = [[DFModalSpinnerViewController alloc]
                                        initWithMessage:@"Verifying..."];
  [self presentViewController:msvc animated:YES completion:nil];
  
  DFUserPeanutAdapter *userAdapter = [[DFUserPeanutAdapter alloc] init];
  
  [userAdapter createUserForDeviceID:[[DFUser currentUser] deviceID]
                          deviceName:[DFUser deviceName]
                         phoneNumber:phoneNumberString
                       smsAuthString:authCodeString
                    withSuccessBlock:^(DFUser *user) {
                      [DFUser setCurrentUser:user];
                      [msvc dismissViewControllerAnimated:YES completion:nil];
                      AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
                      [DFAnalytics logSetupSMSCodeEnteredWithResult:DFAnalyticsValueResultSuccess];
                      [delegate showMainView];
                    }
                        failureBlock:^(NSError *error) {
                          DDLogWarn(@"Create user failed: %@", error.localizedDescription);
                          [msvc dismissViewControllerAnimated:YES completion:^{
                            UIAlertView *failureAlert = [DFSMSCodeEntryViewController accountFailedAlert:error];
                            [failureAlert show];
                            [self resetCodeField];
                            [DFAnalytics logSetupSMSCodeEnteredWithResult:DFAnalyticsValueResultFailure];
                            [self.codeTextField becomeFirstResponder];
                          }];
                        }];
  
}

- (void)resetCodeField
{
  self.codeTextField.text = @"- - - -";
}


+ (UIAlertView *)accountFailedAlert:(NSError *)error
{
  return [[UIAlertView alloc] initWithTitle:@"Account Creation Failed"
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil];
}



@end
