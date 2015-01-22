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
#import "DFContactDataManager.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFSection.h"
#import "DFPeanutFeedDataManager.h"

@interface DFInviteFriendViewController ()

@property (nonatomic, retain) DFSMSInviteStrandComposeViewController *messageComposer;

@end

@implementation DFInviteFriendViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    _peoplePicker = [[DFPeoplePickerViewController alloc] init];
    _peoplePicker.allowsMultipleSelection = YES;
    _peoplePicker.doneButtonActionText = @"Add";
    _peoplePicker.navigationItem.title = @"Add Friends";
    [_peoplePicker setSections:[self.class contactSections]];
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

+ (NSArray *)contactSections
{
  NSMutableArray *sections = [NSMutableArray new];
  
  NSArray *usersWhoAddedYou = [[DFPeanutFeedDataManager sharedManager]
                                usersThatFriendedUser:[[DFUser currentUser] userID] excludeFriends:YES];
  NSArray *contactsWhoAddedYou = [usersWhoAddedYou arrayByMappingObjectsWithBlock:^id(id input) {
    return [[DFPeanutContact alloc] initWithPeanutUser:input];
  }];
  
  if (contactsWhoAddedYou.count > 0) {
    [sections addObject:[DFSection sectionWithTitle:@"People who Added You"
                                             object:nil
                                               rows:contactsWhoAddedYou]];
  }
  
  NSArray *contacts = [[DFContactDataManager sharedManager] allPeanutContacts];
  if (contacts.count > 0) {
    [sections addObject:[DFSection sectionWithTitle:@"Contacts" object:nil rows:contacts]];
  }
  return sections;
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
  NSMutableArray *nonUsersToText = [peanutContacts mutableCopy];
  NSMutableArray *existingUserIDs = [NSMutableArray new];
  for (DFPeanutContact *contact in peanutContacts) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number];
    if (user) {
      [existingUserIDs addObject:@(user.id)];
      [nonUsersToText removeObject:contact];
    }
  }
  
  if (existingUserIDs.count > 0) {
    [[DFPeanutFeedDataManager sharedManager] setUser:[[DFUser currentUser] userID]
                                           isFriends:YES
                                         withUserIDs:existingUserIDs
                                             success:^{
                                               [SVProgressHUD showSuccessWithStatus:@"Added!"];
                                             } failure:^(NSError *error) {
                                               [SVProgressHUD showErrorWithStatus:@"Failed to add users"];
                                               DDLogError(@"%@ adding users failed: %@", self.class, error);
                                             }];
  }
  
  if (nonUsersToText.count > 0) {
    NSArray *phoneNumbers = [nonUsersToText arrayByMappingObjectsWithBlock:^id(DFPeanutContact *contact) {
      return contact.phone_number;
    }];
    self.messageComposer  = [[DFSMSInviteStrandComposeViewController alloc]
                                                               initWithRecipients:phoneNumbers];
    self.messageComposer.messageComposeDelegate = self;
    if (self.messageComposer)
      [self presentViewController:self.messageComposer animated:YES completion:nil];
  } else {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  if (result == MessageComposeResultSent) {
    [[DFContactSyncManager sharedManager]
     uploadInvitedContacts:self.peoplePicker.selectedContacts];
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
