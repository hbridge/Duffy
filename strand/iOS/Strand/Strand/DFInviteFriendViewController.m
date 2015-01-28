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
#import "DFDefaultsStore.h"

@interface DFInviteFriendViewController ()

@property (nonatomic, retain) DFSMSInviteStrandComposeViewController *messageComposer;
@property (nonatomic, retain) NSArray *contactsWhoAddedYou;
@property (nonatomic, retain) NSArray *abContacts;

@end

@implementation DFInviteFriendViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.allowsMultipleSelection = NO;
    self.navigationItem.title = @"Add Friends";
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
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFStrandNewFriendsDataNotificationName
                                             object:nil];
}


- (void)viewDidLoad {
  [super viewDidLoad];
  self.delegate = self;
}



- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableArray *sections = [NSMutableArray new];
    
    // Existing friends
    if (self.showExistingFriendsSection) {
      NSArray *existingFriendUsers = [[DFPeanutFeedDataManager sharedManager] friendsList];
      NSArray *existingFriendContacts = [existingFriendUsers arrayByMappingObjectsWithBlock:^id(id input) {
        return [[DFPeanutContact alloc] initWithPeanutUser:input];
      }];
      if (existingFriendContacts.count > 0) {
        DFSection *friendsSection = [DFSection sectionWithTitle:@"Friends"
                                                         object:nil
                                                           rows:existingFriendContacts];
        [sections addObject:friendsSection];
      }
    }
    
    // People who added you
    NSArray *usersWhoAddedYou = [[DFPeanutFeedDataManager sharedManager]
                                 usersThatFriendedUser:[[DFUser currentUser] userID] excludeFriends:YES];
    self.contactsWhoAddedYou = [usersWhoAddedYou arrayByMappingObjectsWithBlock:^id(id input) {
      return [[DFPeanutContact alloc] initWithPeanutUser:input];
    }];
    if (self.contactsWhoAddedYou.count > 0) {
      DFSection *addedYouSection = [DFSection sectionWithTitle:@"People who Added You"
                                                        object:nil
                                                          rows:self.contactsWhoAddedYou];
      [sections addObject:addedYouSection];
      [self setSecondaryAction:[self addFriendSecondaryAction] forSection:addedYouSection];
    }
    
    // Contacts
    DFSection *allContactsSection = [DFPeoplePickerViewController allContactsSection];
    [sections addObject:allContactsSection];
    [self setSecondaryAction:[self inviteSecondaryAction] forSection:allContactsSection];
    
    //add any actual ab contacts to this row
    self.abContacts = [allContactsSection.rows objectsPassingTestBlock:^BOOL(id input) {
      return [[input class] isSubclassOfClass:[DFPeanutContact class]];
    }];
    
    [self setSections:sections];
  });
}

- (NSDictionary *)analyticsDict
{
  NSArray *friendedYou = [[DFPeanutFeedDataManager sharedManager]
                          usersThatFriendedUser:[[DFUser currentUser] userID] excludeFriends:YES];
  return @{
           @"numAddedYou" : [DFAnalytics bucketStringForObjectCount:friendedYou.count],
           @"contactsPerm" : [DFDefaultsStore stateForPermission:DFPermissionContacts]
           };
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:[self analyticsDict]];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
           contactTapped:(DFPeanutContact *)contact
{
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number];
  if ([[[DFPeanutFeedDataManager sharedManager]
        usersThatFriendedUser:[[DFUser currentUser] userID] excludeFriends:NO]
       containsObject:user]){
    DFFriendProfileViewController *friendController = [[DFFriendProfileViewController alloc]
                                                       initWithPeanutUser:user];
    [self.navigationController pushViewController:friendController animated:YES];
    [DFAnalytics logInviteActionTaken:@"viewFriend" userInfo:[self analyticsDict]];
  }
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{

}

- (DFPeoplePickerSecondaryAction *)addFriendSecondaryAction
{
  DFInviteFriendViewController __weak *weakSelf = self;
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
    [DFAnalytics logInviteActionTaken:@"addBack" userInfo:[weakSelf analyticsDict]];
  };
  return secondaryAction;
}

- (DFPeoplePickerSecondaryAction *)inviteSecondaryAction
{
  DFPeoplePickerSecondaryAction *secondaryAction = [DFPeoplePickerSecondaryAction new];
  secondaryAction.foregroundColor = [UIColor whiteColor];
  secondaryAction.backgroundColor = [DFStrandConstants strandBlue];
  secondaryAction.buttonText = @"Invite";
  secondaryAction.actionHandler = [self inviteActionHandler];
  return secondaryAction;
}

- (DFPeoplePickerSecondaryActionHandler)inviteActionHandler
{
  DFInviteFriendViewController __weak *weakSelf = self;
  return ^(DFPeanutContact *contact) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number];
    if ([user hasAuthedPhone]) {
      [SVProgressHUD showErrorWithStatus:@"Already user"];
      return;
    }
    
    // we call this mapping function to force creation of a userID if none exists
    [[DFPeanutFeedDataManager sharedManager]
     userIDsFromPhoneNumbers:@[contact.phone_number]
     success:^(NSDictionary *phoneNumbersToUserIDs, NSArray *unAuthedPhoneNumbers) {
       [DFSMSInviteStrandComposeViewController
        showWithParentViewController:weakSelf
        phoneNumbers:@[contact.phone_number]
        completionBlock:^(MessageComposeResult result) {
          if (result == MessageComposeResultSent)
            [SVProgressHUD showSuccessWithStatus:@"Sent!"];
          else if (result == MessageComposeResultCancelled)
            [SVProgressHUD showErrorWithStatus:@"Cancelled"];
          
          // force a refresh of users
          [[DFPeanutFeedDataManager sharedManager] refreshUsersFromServerWithCompletion:nil];
        }];
     } failure:^(NSError *error) {
       [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"Failed: %@",
                                            error.localizedDescription]];
     }];
    
    [DFAnalytics logInviteActionTaken:@"invite" userInfo:[weakSelf analyticsDict]];
  };
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
