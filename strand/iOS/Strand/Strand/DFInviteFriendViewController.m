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
#import "DFFriendProfileViewController.h"
#import "DFNotificationSharedConstants.h"

@interface DFInviteFriendViewController ()

@property (nonatomic, retain) DFSMSInviteStrandComposeViewController *messageComposer;

@end

@implementation DFInviteFriendViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    _peoplePicker = [[DFPeoplePickerViewController alloc] init];
    _peoplePicker.allowsMultipleSelection = NO;
    _peoplePicker.navigationItem.title = @"Add Friends";
    [self reloadData];
    [self observeNotifications];
  }
  return self;
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(contactPermissionChanged:)
                                               name:DFContactPermissionChangedNotificationName
                                             object:nil];
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

- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableArray *sections = [NSMutableArray new];
    
    // People who added you
    NSArray *usersWhoAddedYou = [[DFPeanutFeedDataManager sharedManager]
                                 usersThatFriendedUser:[[DFUser currentUser] userID] excludeFriends:YES];
    NSArray *contactsWhoAddedYou = [usersWhoAddedYou arrayByMappingObjectsWithBlock:^id(id input) {
      return [[DFPeanutContact alloc] initWithPeanutUser:input];
    }];
    if (contactsWhoAddedYou.count > 0) {
      DFSection *addedYouSection = [DFSection sectionWithTitle:@"People who Added You"
                                                        object:nil
                                                          rows:contactsWhoAddedYou];
      [sections addObject:addedYouSection];
      [self.peoplePicker setSecondaryAction:[self addFriendSecondaryAction] forSection:addedYouSection];
      self.peoplePicker.notSelectableContacts = contactsWhoAddedYou;
    }
    
    // Contacts
    DFSection *allContactsSection = [DFPeoplePickerViewController allContactsSection];
    [sections addObject:allContactsSection];
    [self.peoplePicker setSecondaryAction:[self inviteSecondaryAction] forSection:allContactsSection];
    
    [self.peoplePicker setSections:sections];
  });
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
           contactTapped:(DFPeanutContact *)contact
{
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number];
  if ([[[DFPeanutFeedDataManager sharedManager]
        usersThatFriendedUser:[[DFUser currentUser] userID] excludeFriends:YES]
       containsObject:user]){
    DFFriendProfileViewController *friendController = [[DFFriendProfileViewController alloc]
                                                       initWithPeanutUser:user];
    [self pushViewController:friendController animated:YES];
  }
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  }

- (DFPeoplePickerSecondaryAction *)addFriendSecondaryAction
{
  DFPeoplePickerSecondaryAction *secondaryAction = [DFPeoplePickerSecondaryAction new];
  secondaryAction.foregroundColor = [UIColor whiteColor];
  secondaryAction.backgroundColor = [DFStrandConstants strandBlue];
  secondaryAction.buttonText = @"Add Back";
  secondaryAction.actionHandler = ^(DFPeanutContact *contact) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number];
    [[DFPeanutFeedDataManager sharedManager] setUser:[[DFUser currentUser] userID]
                                           isFriends:YES
                                         withUserIDs:@[@(user.id)]
                                             success:^{
                                               [SVProgressHUD showSuccessWithStatus:@"Added!"];
                                               [self reloadData];
                                             } failure:^(NSError *error) {
                                               [SVProgressHUD showErrorWithStatus:@"Failed to add users"];
                                               DDLogError(@"%@ adding users failed: %@", self.class, error);
                                             }];
  };
  return secondaryAction;
}

- (DFPeoplePickerSecondaryAction *)inviteSecondaryAction
{
  DFPeoplePickerSecondaryAction *secondaryAction = [DFPeoplePickerSecondaryAction new];
  secondaryAction.foregroundColor = [UIColor whiteColor];
  secondaryAction.backgroundColor = [DFStrandConstants strandBlue];
  secondaryAction.buttonText = @"Invite";
  secondaryAction.actionHandler = ^(DFPeanutContact *contact) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number];
    if ([user hasAuthedPhone]) {
      [SVProgressHUD showErrorWithStatus:@"Already user"];
      return;
    }
    
    [DFSMSInviteStrandComposeViewController
     showWithParentViewController:self
     phoneNumbers:@[contact.phone_number]
     completionBlock:^(MessageComposeResult result) {
       if (result == MessageComposeResultSent) [SVProgressHUD showSuccessWithStatus:@"Sent!"];
       else if (result == MessageComposeResultCancelled) [SVProgressHUD showErrorWithStatus:@"Cancelled"];
     }];
  };
  return secondaryAction;
}

- (void)cancelPressed:(id)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactPermissionChanged:(NSNotification *)note
{
  [self reloadData];
}

@end
