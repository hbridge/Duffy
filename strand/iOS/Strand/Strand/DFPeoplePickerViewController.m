//
//  DFPeoplePickerController.m
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeoplePickerViewController.h"
#import <AddressBook/AddressBook.h>
#import <RHAddressBook/AddressBook.h>
#import "NSString+DFHelpers.h"
#import "DFDefaultsStore.h"
#import "UIAlertView+DFHelpers.h"
#import "DFAnalytics.h"
#import "DFUser.h"
#import "DFPeanutUserObject.h"
#import "DFABResultTableViewCell.h"
#import "DFContactSyncManager.h"


@interface DFPeoplePickerViewController ()

@property (readonly, nonatomic, retain) RHAddressBook *addressBook;
@property (nonatomic, retain) NSMutableArray *selectedContacts;

@end

@implementation DFPeoplePickerViewController
@synthesize addressBook = _addressBook;


- (instancetype)init
{
  self = [super initWithNibName:@"DFPeoplePickerViewController" bundle:nil];
  if (self) {
    
  }
  return self;
}

- (instancetype)initWithTokenField:(VENTokenField *)tokenField tableView:(UITableView *)tableView
{
  return [self initWithTokenField:tokenField withPeanutUsers:nil tableView:tableView];
}

- (instancetype)initWithTokenField:(VENTokenField *)tokenField withPeanutUsers:(NSArray *)peanutUsers tableView:(UITableView *)tableView
{
  self = [super init];
  if (self) {
    self.tableView = tableView;
    self.tokenField = tokenField;
    [self configureTableView];
    [self configureTokenField];
    
    if (peanutUsers) {
      for (DFPeanutUserObject *user in peanutUsers) {
        [self.selectedContacts addObject:[[DFPeanutContact alloc ] initWithPeanutUser:user]];
      }
      
      [self.tokenField reloadData];
    }
    
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureTableView];
  [self configureTokenField];
}

- (void)configureTableView
{
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFABResultTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"abResult"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNoContactsTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"noContacts"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNoResultsTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"noResults"];

}

- (void)configureTokenField
{
  self.selectedContacts = [NSMutableArray new];
  if (!self.tokenField) {
    self.tokenField = [[VENTokenField alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 50)];
    self.tokenField.maxHeight = 50.0;
    self.tokenField.verticalInset = 3.0;
    self.tokenField.backgroundColor = [UIColor whiteColor];
    self.tableView.tableHeaderView = self.tokenField;
  }
  self.tokenField.delegate = self;
  self.tokenField.dataSource = self;
  self.tokenField.placeholderText = @"Enter a name or phone number";
}

- (NSArray *)selectedPeanutContacts
{
  return self.selectedContacts;
}

#pragma mark - Text Field Changes and Filtering

- (void)tokenField:(VENTokenField *)tokenField didChangeText:(NSString *)text
{
  [self updateSearchResults];
  [self.tableView reloadData];
  if ([self.delegate respondsToSelector:@selector(pickerController:textDidChange:)]) {
    [self.delegate pickerController:self textDidChange:text];
  }
}

- (void)updateSearchResults
{
  self.abSearchResults = nil;
  self.textNumberString = nil;
  
  if ([self.tokenField.inputText isNotEmpty]) {
    self.abSearchResults = @[];
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
      self.abSearchResults = [self abSearchResultsForString:self.tokenField.inputText];
    }
    self.textNumberString = [self textNumberStringForString:self.tokenField.inputText];
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
      [self configureABCell:(DFABResultTableViewCell *)cell forIndexPath:indexPath];
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

- (void)configureABCell:(DFABResultTableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath
{
  NSDictionary *resultDict = self.abSearchResults[indexPath.row];
  RHPerson *person = resultDict[@"person"];
  int phoneIndex = [resultDict[@"index"] intValue];
  
  cell.titleLabel.text = person.name;
  cell.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@",
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
  DFPeanutContact *selectedContact;
  if (indexPath.section == 0 && self.abSearchResults.count > 0) {
    NSDictionary *resultDict = self.abSearchResults[indexPath.row];
    RHPerson *person = resultDict[@"person"];
    int phoneIndex = [resultDict[@"index"] intValue];
    selectedContact = [self contactForName:person.name number:[person.phoneNumbers valueAtIndex:phoneIndex]];
  } else if (indexPath.section == 1 && self.textNumberString) {
    selectedContact = [self contactForName:@"" number:self.textNumberString];
  } else if (indexPath.section == 0 && ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) {
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (status == kABAuthorizationStatusNotDetermined) {
      [self askForContactsPermission];
    } else {
      [self showContactsDeniedAlert];
    }
  }
  
  if (selectedContact) {
    if (self.allowsMultipleSelection) {
      [self.selectedContacts addObject:selectedContact];
      [self.tokenField reloadData];
      [self updateSearchResults];
      [self.tableView reloadData];
      [self tokenField:self.tokenField didChangeText:self.tokenField.inputText];
      [self.delegate pickerController:self didPickContacts:self.selectedContacts];
    } else {
      [self.delegate pickerController:self didPickContacts:@[selectedContact]];
    }
  }
  
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (DFPeanutContact *)contactForName:(NSString *)name number:(NSString *)number
{
  DFPeanutContact *contact = [[DFPeanutContact alloc] init];
  contact.name = name;
  contact.phone_number = number;
  contact.user = @([[DFUser currentUser] userID]);
  return contact;
}


#pragma mark - Token Field Delegate/Datasource

-(NSUInteger)numberOfTokensInTokenField:(VENTokenField *)tokenField
{
  return self.selectedContacts.count;
}

- (NSString *)tokenField:(VENTokenField *)tokenField titleForTokenAtIndex:(NSUInteger)index
{
  DFPeanutContact *contact = self.selectedContacts[index];
  return [contact.name isNotEmpty] ? contact.name : contact.phone_number;
}

- (void)tokenField:(VENTokenField *)tokenField didDeleteTokenAtIndex:(NSUInteger)index
{
  [self.selectedContacts removeObjectAtIndex:index];
  [self.tokenField reloadData];
}

#pragma mark - Cotnacts Permission

- (void)askForContactsPermission
{
  DDLogInfo(@"%@ asking for contacts permission", self.class);
  CFErrorRef error;
  ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
  
  ABAuthorizationStatus oldStatus = ABAddressBookGetAuthorizationStatus();
  DFPeoplePickerViewController __weak *weakSelf = self;
  ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
    if (granted) {
      [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionContacts];
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf updateSearchResults];
        [weakSelf.tableView reloadData];
        [[DFContactSyncManager sharedManager] sync];
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


- (RHAddressBook *)addressBook
{
  if (!_addressBook) _addressBook = [[RHAddressBook alloc] init];
  return _addressBook;
}




@end
