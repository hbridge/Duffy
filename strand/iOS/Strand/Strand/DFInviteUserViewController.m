//
//  DFInviteUserViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInviteUserViewController.h"
#import <AddressBook/AddressBook.h>
#import <RHAddressBook/AddressBook.h>
#import "UIAlertView+DFHelpers.h"
#import "DFUserPeanutAdapter.h"
#import "DFPeanutInviteMessageAdapter.h"
#import "NSString+DFHelpers.h"
#import "DFAnalytics.h"
#import "SVProgressHUD.h"
#import "DFDefaultsStore.h"
#import "DFPeanutContactAdapter.h"

@interface DFInviteUserViewController ()

@property (nonatomic, retain) MFMessageComposeViewController *composeController;
@property (readonly, nonatomic, retain) DFUserPeanutAdapter *userAdapter;
@property (nonatomic, retain) DFPeanutInviteMessageAdapter *inviteAdapter;
@property (atomic, retain) DFPeanutInviteMessageResponse *inviteResponse;
@property (nonatomic, retain) NSError *loadInviteMessageError;

@property (nonatomic, retain) DFPeanutContact *selectedContact;


@end

@implementation DFInviteUserViewController

@synthesize userAdapter = _userAdapter;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    self.navigationItem.title = @"Invite Friend";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                             target:self
                                             action:@selector(cancel)];
    self.delegate = self;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.inviteAdapter fetchInviteMessageResponse:^(DFPeanutInviteMessageResponse *response, NSError *error) {
    self.inviteResponse = response;
    self.loadInviteMessageError = error;
    if (error) DDLogError(@"%@ fetching invite response yielded error: %@", self.class, error);
  }];
}


- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  // only handle this logic if this view is appearing for the first time
  if (!self.isMovingToParentViewController) return;

  [self.toTextField becomeFirstResponder];
  [DFAnalytics logViewController:self appearedWithParameters:@{@"result": @"Success"}];
}




#pragma mark - Action Responses

- (void)pickerController:(DFPeoplePickerViewController *)pickerController didPickContact:(DFPeanutContact *)contact
{
  [self showComposerWithPickedContact:contact];
}


- (void)showComposerWithPickedContact:(DFPeanutContact *)pickedContact
{
  [SVProgressHUD show];

  // setup selected contact for use in messageComposeViewController:didFinishWithResult
  self.selectedContact = pickedContact;
  self.selectedContact.contact_type = DFPeanutContactInvited;
  
  // handle the case where we failed to get the invite text at controller init
  if (!self.inviteResponse) {
    // retry getting the invite response, if it fails, show an alert
    DDLogError(@"%@ invite response not set.  Trying to fetch again", self.class);
    [self.inviteAdapter fetchInviteMessageResponse:^(DFPeanutInviteMessageResponse *response, NSError *error) {
      if (!error) {
        self.inviteResponse = response;
        [self showComposerWithPickedContact:pickedContact];
      } else {
        DDLogError(@"%@ could not fetch invite text on retry.", self.class);
        [UIAlertView showSimpleAlertWithTitle:@"Error" formatMessage:@"Could not invite at this time. %@",
         error.localizedDescription];
      }
    }];
    return;
  }
  
  // setup the compose controller and show
  self.composeController = [[MFMessageComposeViewController alloc] init];
  self.composeController.messageComposeDelegate = self;
  self.composeController.recipients = @[pickedContact.phone_number];
  self.composeController.body = self.inviteResponse.invite_message;

  if (self.composeController) {
    [self presentViewController:self.composeController animated:YES completion:^{
      [SVProgressHUD dismiss];
    }];
  } else {
    DDLogError(@"%@ compose controller null", self.class);
    [SVProgressHUD dismiss];
  }
}

#pragma mark - MFMessageComposeViewControllerDelegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  DDLogInfo(@"%@ messageCompose finished with result: %d", [self.class description], result);
  [DFAnalytics logInviteComposeFinishedWithResult:result
                         presentingViewController:self.presentingViewController];
  if (result == MessageComposeResultSent) {
    DFPeanutContactAdapter *contactAdapter = [[DFPeanutContactAdapter alloc] init];
    [contactAdapter
     postPeanutContacts:@[self.selectedContact]
     success:^(NSArray *peanutContacts) {
       DDLogInfo(@"%@ successfully posted contact: %@", self.class, self.selectedContact);
     } failure:^(NSError *error) {
       DDLogInfo(@"%@ failed to post contact: %@", self.class, self.selectedContact);
     }];
    [self.presentingViewController
     dismissViewControllerAnimated:YES
     completion:^{
       [SVProgressHUD showSuccessWithStatus:@"Sent!"];
     }];
    
  } else {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}



- (void)cancel
{
  [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Adapters and AB getters

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) _userAdapter = [[DFUserPeanutAdapter alloc] init];
  return _userAdapter;
}

- (DFPeanutInviteMessageAdapter *)inviteAdapter
{
  if (!_inviteAdapter) {
    _inviteAdapter = [[DFPeanutInviteMessageAdapter alloc] init];
  }
  
  return _inviteAdapter;
}


@end
