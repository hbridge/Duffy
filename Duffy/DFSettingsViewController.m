//
//  DFSettingsViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSettingsViewController.h"
#import <CocoaLumberjack/DDFileLogger.h>
#import "DFPhotoStore.h"
#import "DFUploadController.h"
#import "DFUser.h"
#import "DFAnalytics.h"
#import "DFNotificationSharedConstants.h"
#import "DFAppInfo.h"
#import "DFDevelopmentSettingsViewController.h"
#import "DFDiagnosticInfoMailComposeController.h"

@interface DFSettingsViewController ()

@property (nonatomic, retain) UIView *lastEditedTextField;

@end

@implementation DFSettingsViewController

- (id)init
{
  self = [super init];
  if (self) {
    self.navigationItem.title = @"Settings";
    self.tabBarItem.title = @"Settings";
    self.tabBarItem.image = [UIImage imageNamed:@"Icons/SettingsTab"];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureAppInfoView];
  [self configureUserSectionView];
  [self configureNetworkSectionView];
  
}

- (void)configureAppInfoView
{
  self.appInfoLabel.text = [DFAppInfo appInfoString];
}

- (void)configureUserSectionView
{
  self.userIDTextField.text = [NSString stringWithFormat:@"%lu", (long)[[DFUser currentUser] userID]];
}


- (void)configureNetworkSectionView
{
  if ([[DFUser currentUser] autoUploadEnabled]){
    self.autoUploadEnabledSwitch.on = YES;
  } else {
    self.autoUploadEnabledSwitch.on = NO;
  }
  
  if ([[DFUser currentUser] conserveDataEnabled]){
    self.conserveDataEnabledSwitch.on = YES;
  } else {
    self.conserveDataEnabledSwitch.on = NO;
  }
  
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardDidShow:)
                                               name:UIKeyboardDidShowNotification
                                             object:nil];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIKeyboardDidShowNotification
                                                object:nil];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}


- (IBAction)cancelUpload:(UIButton *)sender {
  [[DFUploadController sharedUploadController] cancelUploads];
}

- (IBAction)sendInfoClicked:(UIButton *)sender {
  if ([MFMailComposeViewController canSendMail]) {
    DFDiagnosticInfoMailComposeController *mailViewController = [[DFDiagnosticInfoMailComposeController alloc] init];
    mailViewController.mailComposeDelegate = self;
    [self presentViewController:mailViewController animated:YES completion:nil];
  } else {
    NSString *message = NSLocalizedString(@"Sorry, your issue can't be reported right now. This is most likely because no mail accounts are set up on your mobile device.", @"");
    [[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles: nil] show];
  }
  
}

- (IBAction)developerSettingsClicked:(UIButton *)sender {
  DFDevelopmentSettingsViewController *dsvc = [[DFDevelopmentSettingsViewController alloc] init];
  [self.navigationController pushViewController:dsvc animated:YES];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error;
{
  if (result == MFMailComposeResultSent) {
    DDLogInfo(@"Feedback email sent.");
  }
  
  [self dismissViewControllerAnimated:YES completion:nil];
}



- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  [textField resignFirstResponder];
  return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
  return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
  self.lastEditedTextField = textField;
}

- (IBAction)autoUploadEnabledSwitchChanged:(UISwitch *)sender {
  [[DFUser currentUser] setAutoUploadEnabled:sender.isOn];
  [DFAnalytics logAutoUploadSettingChanged:sender.isOn];
}

- (IBAction)conserveDataEnabledSwitchChanged:(UISwitch *)sender {
  [[DFUser currentUser] setConserveDataEnabled:sender.isOn];
  [DFAnalytics logAutoUploadSettingChanged:sender.isOn];
}

- (void)keyboardDidShow:(NSNotification *)notification {
  if (self.lastEditedTextField && self.lastEditedTextField.isFirstResponder) {
    [self scrollToView:self.lastEditedTextField];
  }
}

- (void)scrollToView:(UIView *)view
{
  CGRect rectInScrollView = [self.scrollView convertRect:view.frame fromView:view.superview];
  self.scrollView.contentOffset = rectInScrollView.origin;
}

- (IBAction)scrollViewTapped:(UITapGestureRecognizer *)sender {
  if (self.lastEditedTextField && self.lastEditedTextField.isFirstResponder) {
    [self.lastEditedTextField resignFirstResponder];
  }
  
}





@end
