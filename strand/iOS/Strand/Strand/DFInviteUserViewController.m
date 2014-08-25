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
@property (nonatomic, retain) UITextField *toTextField;
@property (nonatomic, retain) NSArray *abSearchResults;
@property (nonatomic, retain) NSString *textNumberString;
@property (readonly, nonatomic, retain) RHAddressBook *addressBook;
@property (nonatomic, retain) DFPeanutContact *selectedContact;

@end

@implementation DFInviteUserViewController

@synthesize userAdapter = _userAdapter;
@synthesize addressBook = _addressBook;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    self.navigationItem.title = @"Invite Friend";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                             target:self
                                             action:@selector(cancel)];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFABResultTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"abResult"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNoContactsTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"noContacts"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNoResultsTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"noResults"];

  [self configureToField];
  
  [self.inviteAdapter fetchInviteMessageResponse:^(DFPeanutInviteMessageResponse *response, NSError *error) {
    self.inviteResponse = response;
    self.loadInviteMessageError = error;
    if (error) DDLogError(@"%@ fetching invite response yielded error: %@", self.class, error);
  }];
}

- (void)configureToField
{
  self.toTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
  self.toTextField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 44)];
  self.toTextField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 44)];
  self.toTextField.leftViewMode = self.toTextField.rightViewMode = UITextFieldViewModeAlways;
  self.toTextField.delegate = self;
  self.toTextField.placeholder = @"Enter a name or phone number";
  self.toTextField.backgroundColor = [UIColor whiteColor];
  self.toTextField.keyboardType = UIKeyboardTypeNamePhonePad;
  self.toTextField.autocorrectionType = UITextAutocorrectionTypeNo;
  self.tableView.tableHeaderView = self.toTextField;
  [self.toTextField addTarget:self
                       action:@selector(textFieldChanged:)
             forControlEvents:UIControlEventEditingChanged];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  // only handle this logic if this view is appearing for the first time
  if (!self.isMovingToParentViewController) return;

  [self.toTextField becomeFirstResponder];
  [DFAnalytics logViewController:self appearedWithParameters:@{@"result": @"Success"}];
}


#pragma mark - Text Field Changes and Filtering

- (void)textFieldChanged:(id)sender
{
  [self updateSearchResults];
  [self.tableView reloadData];
}

- (void)updateSearchResults
{
  self.abSearchResults = nil;
  self.textNumberString = nil;
  
  if ([self.toTextField.text isNotEmpty]) {
    self.abSearchResults = @[];
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
      self.abSearchResults = [self abSearchResultsForString:self.toTextField.text];
    }
    self.textNumberString = [self textNumberStringForString:self.toTextField.text];
  }
}

- (NSArray *)abSearchResultsForString:(NSString *)string
{
  if (ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) return @[];
  
  NSMutableArray *results = [NSMutableArray new];
  NSArray *people = [self.addressBook peopleWithName:string];
  for (RHPerson *person in people) {
    for (int i = 0; i < person.phoneNumbers.values.count; i++) {
      NSDictionary *resultDict = @{
                                   @"person": person,
                                   @"index": @(i),
                                   };
      [results addObject:resultDict];
    }
  }
  
  return results;
}

- (NSString *)textNumberStringForString:(NSString *)string
{
  static NSRegularExpression *phoneNumberRegex = nil;
  if (!phoneNumberRegex) {
    NSError *error;
    phoneNumberRegex = [NSRegularExpression regularExpressionWithPattern:@"^[2-9][0-9]{9}$" options:0 error:&error];
    if (error) {
      [NSException raise:@"Bad regex" format:@"Error: %@", error];
    }
  }
  
  if ([[phoneNumberRegex matchesInString:string options:0 range:[string fullRange]] count] > 0) {
    return string;
  }

  return nil;
}

#pragma mark - Table View Datasource and Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  NSInteger result = 0;
  if (self.abSearchResults) result += 1;
  if (self.textNumberString) result += 1;
  
  return result;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == 0) return @"Contacts";
  if (section == 1) return @"Text Phone Number";
  return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return 30.0;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0) {
    return MAX(self.abSearchResults.count, 1);
  } else if (section == 1) {
    return self.textNumberString ? 1 : 0;
  }
  
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  
  if (indexPath.section == 0) {
    if (self.abSearchResults.count > 0) {
      cell = [self.tableView dequeueReusableCellWithIdentifier:@"abResult"];
      [self configureABCell:cell forIndexPath:indexPath];
      cell.imageView.image = nil;
    } else if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined) {
      cell = [self.tableView dequeueReusableCellWithIdentifier:@"noContacts"];
    } else {
      cell = [self.tableView dequeueReusableCellWithIdentifier:@"noResults"];
    }
  } else if (indexPath.section == 1) {
    cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.textLabel.text = [NSString stringWithFormat:@"Text %@", self.textNumberString];
    cell.imageView.image = [UIImage imageNamed:@"SMSTableCellIcon"];
  }
    
  return cell;
}

- (void)configureABCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath
{
  NSDictionary *resultDict = self.abSearchResults[indexPath.row];
  RHPerson *person = resultDict[@"person"];
  int phoneIndex = [resultDict[@"index"] intValue];
  
  cell.textLabel.text = person.name;
  cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@",
                               [person.phoneNumbers localizedLabelAtIndex:phoneIndex],
                               [person.phoneNumbers valueAtIndex:phoneIndex]
                               ];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 0) {
    if (self.abSearchResults.count > 0) return 44.0;
    return 91.0;
  }
  
  return 44.0;
}

#pragma mark - Action Responses

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 0 && self.abSearchResults.count > 0) {
    NSDictionary *resultDict = self.abSearchResults[indexPath.row];
    RHPerson *person = resultDict[@"person"];
    int phoneIndex = [resultDict[@"index"] intValue];
    [self showComposerWithName:person.name phoneNumber:[person.phoneNumbers valueAtIndex:phoneIndex]];
  } else if (indexPath.section == 1 && self.textNumberString) {
    [self showComposerWithName:self.textNumberString phoneNumber:self.textNumberString];
  } else if (indexPath.section == 0 && ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) {
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (status == kABAuthorizationStatusNotDetermined) {
      [self askForContactsPermission];
    } else {
      [self showContactsDeniedAlert];
    }
  }
  
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)showComposerWithName:(NSString *)name phoneNumber:(NSString *)phoneNumber
{
  [SVProgressHUD show];

  // setup selected contact for use in messageComposeViewController:didFinishWithResult
  self.selectedContact = [[DFPeanutContact alloc] init];
  self.selectedContact.name = name;
  self.selectedContact.phone_number = phoneNumber;
  self.selectedContact.contact_type = DFPeanutContactInvited;
  self.selectedContact.user = @([[DFUser currentUser] userID]);
  
  // handle the case where we failed to get the invite text at controller init
  if (!self.inviteResponse) {
    // retry getting the invite response, if it fails, show an alert
    DDLogError(@"%@ invite response not set.  Trying to fetch again", self.class);
    [self.inviteAdapter fetchInviteMessageResponse:^(DFPeanutInviteMessageResponse *response, NSError *error) {
      if (!error) {
        self.inviteResponse = response;
        [self showComposerWithName:name phoneNumber:phoneNumber];
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
  self.composeController.recipients = @[phoneNumber];
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

- (void)askForContactsPermission
{
  DDLogInfo(@"%@ asking for contacts permission", self.class);
  CFErrorRef error;
  ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
  
  ABAuthorizationStatus oldStatus = ABAddressBookGetAuthorizationStatus();
  DFInviteUserViewController __weak *weakSelf = self;
  ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
    if (granted) {
      [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionContacts];
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf updateSearchResults];
        [weakSelf.tableView reloadData];
      });
    } else {
      [weakSelf showContactsDeniedAlert];
    }
    
    [DFAnalytics logInviteAskContactsWithParameters:@{
                                                      @"oldValue": @(oldStatus),
                                                      @"newValue": @(ABAddressBookGetAuthorizationStatus())
                                                      }];

  });
}

- (void)showContactsDeniedAlert
{
  [UIAlertView showSimpleAlertWithTitle:@"Contacts Denied"
                          formatMessage:@"Please go to Settings > Privacy > Contacts and change Strand to on."];
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

- (RHAddressBook *)addressBook
{
  if (!_addressBook) _addressBook = [[RHAddressBook alloc] init];
  return _addressBook;
}

@end
