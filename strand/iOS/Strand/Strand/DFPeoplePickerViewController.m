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


@interface DFPeoplePickerViewController ()

@property (readonly, nonatomic, retain) RHAddressBook *addressBook;

@end

@implementation DFPeoplePickerViewController
@synthesize addressBook = _addressBook;


- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    
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
    DFPeanutContact *contact = [self contactForName:person.name number:[person.phoneNumbers valueAtIndex:phoneIndex]];
    [self.delegate pickerController:self didPickContact:contact];
  } else if (indexPath.section == 1 && self.textNumberString) {
    DFPeanutContact *contact = [self contactForName:@"" number:self.textNumberString];
    [self.delegate pickerController:self didPickContact:contact];
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


- (DFPeanutContact *)contactForName:(NSString *)name number:(NSString *)number
{
  DFPeanutContact *contact = [[DFPeanutContact alloc] init];
  contact.name = name;
  contact.phone_number = number;
  contact.user = @([[DFUser currentUser] userID]);
  return contact;
}

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
