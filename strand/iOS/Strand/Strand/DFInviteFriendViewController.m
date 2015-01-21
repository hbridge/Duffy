//
//  DFInviteFriendViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInviteFriendViewController.h"
#import "DFAnalytics.h"
#import "DFSMSInviteStrandComposeViewController.h"
#import "DFContactSyncManager.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface DFInviteFriendViewController ()

@property (nonatomic, retain) DFSMSInviteStrandComposeViewController *messageComposer;

@end

@implementation DFInviteFriendViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    _peoplePicker = [[DFPeoplePickerViewController alloc] init];
    _peoplePicker.hideFriendsSection = YES;
    _peoplePicker.allowsMultipleSelection = YES;
    _peoplePicker.doneButtonActionText = @"Invite";
    _peoplePicker.navigationItem.title = @"Invite Friends";
    _peoplePicker.showUsersThatAddedYouSection = YES;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.peoplePicker.delegate = self;
  
  [self pushViewController:self.peoplePicker animated:NO];
  self.peoplePicker.navigationItem.leftBarButtonItem  = [[UIBarButtonItem alloc]
                                                         initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                         target:self
                                                         action:@selector(cancelPressed:)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  if (peanutContacts.count > 0) {
    NSArray *phoneNumbers = [peanutContacts arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
      return contact.phone_number;
    }];
    self.messageComposer  = [[DFSMSInviteStrandComposeViewController alloc]
                                                               initWithRecipients:phoneNumbers];
    self.messageComposer.messageComposeDelegate = self;
    if (self.messageComposer)
      [self presentViewController:self.messageComposer animated:YES completion:nil];
  }
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  if (result == MessageComposeResultSent) {
    [[DFContactSyncManager sharedManager]
     uploadInvitedContacts:self.peoplePicker.selectedPeanutContacts];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^(void) {
      [SVProgressHUD showSuccessWithStatus:@"Sent!"];
    }];
  } else {
    [self.messageComposer dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)cancelPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

@end
