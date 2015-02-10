//
//  DFFirstTimeSetupViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateAccountViewController.h"
#import <ActionSheetPicker-3.0/ActionSheetStringPicker.h>
#import <libPhoneNumber-iOS/NBMetadataHelper.h>
#import <libPhoneNumber-iOS/NBAsYouTypeFormatter.h>
#import <libPhoneNumber-iOS/NBPhoneNumberUtil.h>
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "AppDelegate.h"
#import "DFSMSAuthViewController.h"
#import "NSString+DFHelpers.h"
#import "DFSMSVerificationAdapter.h"
#import "DFWebViewController.h"
#import "DFNetworkingConstants.h"
#import "DFAnalytics.h"
#import "SVProgressHUD.h"

@interface DFCreateAccountViewController ()

@property (nonatomic, retain) NSString *selectedRegion;
@property (nonatomic, retain) NBAsYouTypeFormatter *phoneNumberFormatter;

@end

@implementation DFCreateAccountViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
      self.navigationItem.title = @"Create Account";
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
  self.termsButton.titleLabel.numberOfLines = 0;
  self.termsButton.titleLabel.textAlignment = NSTextAlignmentCenter;
  self.nameTextField.text = [DFUser deviceNameBasedUserName];
  if ([self.nameTextField.text isEqualToString:@"iPhone"]) {
    self.nameTextField.text = @"";
  }
  self.selectedRegion = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:YES];
  [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersStatusBarHidden
{
  return NO;
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

- (IBAction)phoneNumberFieldValueChanged:(UITextField *)sender {
  [self textFieldChanged];
  if (sender == self.phoneNumberField) {
    NSString *formattedString = [self.phoneNumberFormatter inputString:[self enteredPhoneNumber]];
    self.phoneNumberField.text = formattedString;
  }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
  if (textField == self.countryTextField || textField == self.countryCodeLabel) {
    [self showCountryCodePicker:textField];
    return NO;
  }
  return YES;
}

- (IBAction)nameTextFieldChanged:(UITextField *)sender {
  [self textFieldChanged];
}

- (void)textFieldChanged
{
  if (self.phoneNumberField.text.length && self.nameTextField.text.length > 0) {
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
  NSString __block *phoneNumberString = [self E164FormattedPhoneNumber];
  [SVProgressHUD show];
  
  DFSMSVerificationAdapter *smsAdapter = [[DFSMSVerificationAdapter alloc] init];
  [smsAdapter
   requestSMSCodeForPhoneNumber:phoneNumberString
   withCompletionBlock:^(DFPeanutTrueFalseResponse *response, NSError *error) {
     if (response.result) {
       [SVProgressHUD dismiss];
       [self showNextStepWithPhoneNumber:phoneNumberString];
       [DFAnalytics logSetupPhoneNumberEnteredWithResult:DFAnalyticsValueResultSuccess];
     } else {
       [SVProgressHUD dismiss];
       UIAlertView *failureAlert = [DFCreateAccountViewController smsVerificationRequestFailed:error];
       [failureAlert show];
       [DFAnalytics logSetupPhoneNumberEnteredWithResult:DFAnalyticsValueResultFailure];
     }
   }];
}

- (NSString *)E164FormattedPhoneNumber
{
  NBPhoneNumberUtil *phoneUtil = [[NBPhoneNumberUtil alloc] init];
  NSError *error = nil;
  NBPhoneNumber *myNumber = [phoneUtil parse:[self enteredPhoneNumber]
                               defaultRegion:self.selectedRegion
                                       error:&error];
  if (error == nil) {
    // Should check error
    return [phoneUtil format:myNumber
                numberFormat:NBEPhoneNumberFormatE164
                       error:&error];
  } else {
    DDLogInfo(@"Error formatting into E164 %@", [error localizedDescription]);
    return nil;
  }
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
  return [[self.phoneNumberField.text
           componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]]
          componentsJoinedByString:@""];
}


- (BOOL)isCurrentPhoneNumberValid
{
  NBPhoneNumberUtil *phoneUtil = [[NBPhoneNumberUtil alloc] init];
  NSError *anError = nil;
  NBPhoneNumber *myNumber = [phoneUtil parse:[self enteredPhoneNumber]
                               defaultRegion:self.selectedRegion
                                       error:&anError];
  if (anError == nil) {
    // Should check error
    BOOL isValid = [phoneUtil isValidNumber:myNumber];
    DDLogInfo(@"%@ isValidPhoneNumber ? [%@]", [self enteredPhoneNumber], isValid ? @"YES":@"NO");
    return isValid;
  } else {
    DDLogInfo(@"Error parsing %@ : %@", [self enteredPhoneNumber], [anError localizedDescription]);
    return NO;
  }
}

- (void)showInvalidNumberAlert:(NSString *)phoneNumber
{
  NSString *formattedNumber = [self E164FormattedPhoneNumber];
  if (![formattedNumber isNotEmpty]) formattedNumber = phoneNumber;
  UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:@"Invalid Phone Number"
                        message:[NSString stringWithFormat:@"%@ is not a valid phone number."
                                 " Please enter a valid mobile phone number.",
                                 formattedNumber]
                        delegate:nil
                        cancelButtonTitle:@"OK"
                        otherButtonTitles:nil];
  [alert show];
}

#pragma mark - Terms button handlers

- (IBAction)phoneFieldTapped:(id)sender {
  // the phone number text field has a view on top of it to prevent
  // copy paste, so we forward taps to activate it here
  [self.phoneNumberField becomeFirstResponder];
}

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

- (void)showNextStepWithPhoneNumber:(NSString *)phoneNumberString
{
  NSString *name;
  if (self.nameTextField.text
      && ![self.nameTextField.text isEqualToString:@""]) {
    name = self.nameTextField.text;
  } else {
    name = [DFUser deviceNameBasedUserName];
  }

  NSDictionary *newUserInfo = @{
                                DFPhoneNumberNUXUserInfoKey : phoneNumberString,
                                DFDisplayNameNUXUserInfoKey : name
                                };
  [self completedWithUserInfo:newUserInfo];
}

#pragma mark - International Support

- (void)showCountryCodePicker:(id)sender {
  NSUInteger indexOfCurrentSelection = [[self.class supportedRegionCodes] indexOfObject:self.selectedRegion];
  [ActionSheetStringPicker
   showPickerWithTitle:@"Select Country"
   rows:[self.class countrySelectorOptions]
   initialSelection: indexOfCurrentSelection != NSNotFound ? indexOfCurrentSelection : 0
   doneBlock:^(ActionSheetStringPicker *picker, NSInteger selectedIndex, id selectedValue) {
     self.selectedRegion = [[self.class supportedRegionCodes] objectAtIndex:selectedIndex];
   }
   cancelBlock:^(ActionSheetStringPicker *picker) {
     NSLog(@"Block Picker Canceled");
   }
   origin:sender];
}

- (void)setSelectedRegion:(NSString *)selectedRegion
{
  _selectedRegion = selectedRegion;
  
  self.countryTextField.text = [self.class localizedCountryNameForRegion:selectedRegion];
  self.countryCodeLabel.text = [@"+" stringByAppendingString:[NBMetadataHelper
                                                              countryCodeFromRegionCode:selectedRegion]];
  self.phoneNumberFormatter = [[NBAsYouTypeFormatter alloc] initWithRegionCode:selectedRegion];
  [self phoneNumberFieldValueChanged:self.phoneNumberField];
}

+ (NSString *)localizedCountryNameForRegion:(NSString *)regionCode
{
  // get the name of the selected region in the current user's language
  id countryDictionaryInstance = [NSDictionary dictionaryWithObject:regionCode
                                                             forKey:NSLocaleCountryCode];
  NSString *identifier = [NSLocale localeIdentifierFromComponents:countryDictionaryInstance];
  NSString *country = [[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:identifier];
  return country;
}

+ (NSArray *)countrySelectorOptions
{
  NSMutableArray *options = [NSMutableArray new];
  NSArray *regionCodes = [self supportedRegionCodes];
  for (NSString *regionCode in regionCodes) {
    NSString *countryCode = [NBMetadataHelper countryCodeFromRegionCode:regionCode];
    NSString *option = [NSString stringWithFormat:@"%@ +%@",
                        [self localizedCountryNameForRegion:regionCode],
                        countryCode];
    [options addObject:option];
  }
  
  return options;
}

+ (NSArray *)supportedRegionCodes
{
  return @[
           @"AE",
           @"AT",
           @"AU",
           @"BE",
           @"BR",
           @"CH",
           @"DE",
           @"DK",
           @"ES",
           @"FI",
           @"FR",
           @"GB",
           @"HK",
           @"ID",
           @"IE",
           @"IL",
           @"IN",
           @"IS",
           @"IT",
           @"JP",
           @"KR",
           @"MX",
           @"NL",
           @"NO",
           @"NZ",
           @"PL",
           @"PT",
           @"RU",
           @"SG",
           @"SE",
           @"TR",
           @"TW",
           @"US",
           ];
}


@end
