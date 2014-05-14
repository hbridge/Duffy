//
//  DFDevelopmentSettingsViewController.m
//  Duffy
//
//  Created by Henry Bridge on 5/14/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFDevelopmentSettingsViewController.h"
#import "DFUser.h"
#import "DFAnalytics.h"
#import "DFPhotoStore.h"
#import "DFUploadController.h"

@interface DFDevelopmentSettingsViewController ()

@property (nonatomic, retain) UIView *lastEditedTextField;


@end

@implementation DFDevelopmentSettingsViewController

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
  
  [self configureDeviceSectionView];
  [self configureServerSectionView];
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


- (void)configureDeviceSectionView
{
  self.deviceIDLabel.text = [[DFUser currentUser] hardwareDeviceID];
  self.deviceIDTextField.text = [[DFUser currentUser] userOverriddenDeviceID];
  self.deviceIDTextField.placeholder = @"Enter another device ID to override.";
  
#ifndef DEBUG
  self.deviceIDTextField.enabled = NO;
  self.deviceIDTextField.placeholder = @"Disabled in release builds.";
#endif

}

- (void)configureServerSectionView
{
  self.serverURLTextField.text = [[DFUser currentUser] userOverriddenServerURLString];
  self.serverURLTextField.placeholder = [[[DFUser currentUser] defaultServerURL] absoluteString];
  self.serverPortTextField.text = [[DFUser currentUser] userOverriddenServerPortString];
  self.serverPortTextField.placeholder = [[DFUser currentUser] defaultServerPort];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)deviceIDEditingDidEnd:(UITextField *)sender {
  [[DFUser currentUser] setUserOverriddenDeviceID:sender.text];
  [self alertUserAndStopApp];
}


- (void)alertUserAndStopApp
{
  [[NSUserDefaults standardUserDefaults] synchronize];
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Duffy Must Close"
                                                  message:@"The app must close for this change to take effect."
                                                 delegate:nil
                                        cancelButtonTitle:@"OK"
                                        otherButtonTitles:nil];
  alert.delegate = self;
  [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  exit(0);
}

- (IBAction)copyDeviceIDClicked:(UIButton *)sender {
  UIPasteboard *pb = [UIPasteboard generalPasteboard];
  [pb setString:[[DFUser currentUser] deviceID]];
}

- (IBAction)serverURLEditingDidEnd:(UITextField *)sender {
  [[DFUser currentUser] setUserOverriddenServerURLString:sender.text];
}

- (IBAction)serverPortEditingDidEnd:(UITextField *)sender {
  [[DFUser currentUser] setUserOverriddenServerPortString:sender.text];
}


- (IBAction)clearUploadDatabaseClicked:(UIButton *)sender {
  [[DFPhotoStore sharedStore] clearUploadInfo];
  [[DFUploadController sharedUploadController] uploadPhotos];
}


- (IBAction)crashAppClicked:(UIButton *)sender {
  [NSException raise:@"Testing Crash" format:@"Intentionally crashing app to test crash uploads."];
}






#pragma mark - TextField Delegate

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
