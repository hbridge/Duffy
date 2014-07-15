//
//  DFFirstTimeSetupViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFirstTimeSetupViewController.h"
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "AppDelegate.h"
#import "DFModalSpinnerViewController.h"
#import "DFSMSCodeEntryViewController.h"
#import "NSString+DFHelpers.h"
#import "DFSMSVerificationAdapter.h"
#import "DFWebViewController.h"
#import "DFNetworkingConstants.h"
#import "DFAnalytics.h"

UInt16 const DFPhoneNumberLength = 10;

@interface DFFirstTimeSetupViewController ()

@end

@implementation DFFirstTimeSetupViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
      self.navigationItem.title = @"Phone Number";
      self.doneBarButtonItem = [[UIBarButtonItem alloc]
                                initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                target:self
                                action:@selector(phoneNumberDoneButtonPressed:)];
      self.doneBarButtonItem.enabled = NO;
      self.navigationItem.rightBarButtonItem = self.doneBarButtonItem;
      
    }
    return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  // Do any additional setup after loading the view from its nib.
  self.phoneNumberField.delegate = self;
  [self.phoneNumberField becomeFirstResponder];
  self.termsButton.titleLabel.numberOfLines = 0;
  self.termsButton.titleLabel.textAlignment = NSTextAlignmentCenter;
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



- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
  // dash after 3 numbers
  if (range.location == 2 && ![string isEqualToString:@""]) {
    textField.text = [textField.text stringByAppendingString:[NSString stringWithFormat:@"%@-", string]];
    return  NO;
  } else if (range.location == 3 && [string isEqualToString:@""]) {
    textField.text = [textField.text substringToIndex:2];
    return NO;
  }
  
  // dash after 6 numbers
  if (range.location == 6 && ![string isEqualToString:@""]) {
    textField.text = [textField.text stringByAppendingString:[NSString stringWithFormat:@"%@-", string]];
    return NO;
  } else if (range.location == 7 && [string isEqualToString:@""]) {
    textField.text = [textField.text substringToIndex:6];
    return NO;
  }
  
  // max length
  if ([[textField.text stringByReplacingCharactersInRange:range withString:string] length] > 12) {
    return NO;
  }
  
  return YES;
}


- (IBAction)phoneNumberFieldValueChanged:(UITextField *)sender {
  if (sender.text.length > 0) {
    self.doneBarButtonItem.enabled = YES;
  } else {
    self.doneBarButtonItem.enabled = NO;
  }
}



- (void)phoneNumberDoneButtonPressed:(id)sender
{
  if (![self isCurrentPhoneNumberValid]) {
    [self showInvalidNumberAlert:[self enteredPhoneNumber]];
    [DFAnalytics logSetupPhoneNumberEnteredWithResult:DFAnalyticsValueResultInvalidInput];
    return;
  }
    NSString __block *phoneNumberString = [self enteredPhoneNumber];
  DFModalSpinnerViewController *msvc = [[DFModalSpinnerViewController alloc]
                                        initWithMessage:[NSString stringWithFormat:@"Sending SMS to %@",
                                                         phoneNumberString]];
  [self presentViewController:msvc animated:YES completion:nil];

  
  DFSMSVerificationAdapter *smsAdapter = [[DFSMSVerificationAdapter alloc] init];
  [smsAdapter requestSMSCodeForPhoneNumber:phoneNumberString
                       withCompletionBlock:^(DFPeanutTrueFalseResponse *response, NSError *error) {
                         if (response.result) {
                           DFSMSCodeEntryViewController *codeEntryController = [[DFSMSCodeEntryViewController alloc] init];
                           codeEntryController.phoneNumberString = phoneNumberString;
                           [self.navigationController pushViewController:codeEntryController
                                                                animated:NO];
                           [msvc dismissViewControllerAnimated:NO completion:nil];
                           [DFAnalytics logSetupPhoneNumberEnteredWithResult:DFAnalyticsValueResultSuccess];
                         } else {
                           UIAlertView *failureAlert = [DFFirstTimeSetupViewController smsVerificationRequestFailed:error];
                           [msvc dismissViewControllerAnimated:YES completion:nil];
                           [failureAlert show];
                           [DFAnalytics logSetupPhoneNumberEnteredWithResult:DFAnalyticsValueResultFailure];
                         }
  }];
  
  
}

+ (UIAlertView *)smsVerificationRequestFailed:(NSError *)error
{
  return [[UIAlertView alloc] initWithTitle:@"Error"
                                    message:[NSString stringWithFormat:@"%@. %@",
                                             error.localizedDescription,
                                             error.localizedRecoverySuggestion ?
                                             error.localizedRecoverySuggestion : @"Please try again."]
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil];

}

- (NSString *)enteredPhoneNumber
{
  NSMutableString *mutableCode = self.phoneNumberField.text.mutableCopy;
  [mutableCode replaceOccurrencesOfString:@"-" withString:@"" options:0 range:mutableCode.fullRange];
  [mutableCode insertString:@"+1" atIndex:0];
  return mutableCode;
}


- (BOOL)isCurrentPhoneNumberValid
{
  NSError *error;
  NSRegularExpression *regex = [[NSRegularExpression alloc]
                                initWithPattern:[NSString stringWithFormat:@"\\d{%d}",DFPhoneNumberLength]
                                options:0
                                error:&error];
  if (error) {
    [NSException raise:@"Invalid Regex" format:@"Error: %@", error.description];
  }
  
  return [regex numberOfMatchesInString:[self enteredPhoneNumber]
                                options:0
                                  range:(NSRange){0, [[self enteredPhoneNumber] length]}
          ] == 1;
}

- (void)showInvalidNumberAlert:(NSString *)phoneNumber
{
  UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:@"Invalid Phone Number"
                        message:[NSString stringWithFormat:@"%@ is not a valid phone number."
                                 " Please enter your %d digit mobile phone number.",
                                 phoneNumber, DFPhoneNumberLength]
                        delegate:nil
                        cancelButtonTitle:@"OK"
                        otherButtonTitles:nil];
  [alert show];
}

#pragma mark - Terms button handlers

- (IBAction)termsButtonPressed:(id)sender {
  UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                initWithTitle:nil
                                delegate:self
                                cancelButtonTitle:@"Cancel"
                                destructiveButtonTitle:nil
                                otherButtonTitles:@"Terms and Conditions", @"Privacy Policy", nil];
  [actionSheet showInView:self.view];
  
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSURL *url;
  if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Terms and Conditions"]) {
    url = [NSURL URLWithString:DFTermsPageURLString];
  } else if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Privacy Policy"]) {
    url = [NSURL URLWithString:DFPrivacyPageURLString];
  }
  
  if (url) {
    DFWebViewController *wvc = [[DFWebViewController alloc] initWithURL:url];
    UINavigationController *navController = [[UINavigationController alloc]
                                             initWithRootViewController:wvc];
    [self presentViewController:navController animated:YES completion:nil];
  }
}



@end
