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
@property (nonatomic, retain) NSArray *unfilteredSectionTitles;
@property (nonatomic, retain) NSArray *unfilteredSections;
@property (nonatomic, retain) NSArray *suggestedList;
@property (nonatomic, retain) NSArray *onStrandList;
@property (nonatomic, retain) NSArray *ABList;
@property (nonatomic, retain) NSMutableArray *selectedContacts;
@property (nonatomic) BOOL isSearching;

@property (nonatomic, retain) NSArray *filteredSectionTitles;
@property (nonatomic, retain) NSArray *filteredSections;
@property (nonatomic, retain) NSArray *filteredSuggestedList;
@property (nonatomic, retain) NSArray *filteredOnStrandList;
@property (nonatomic, retain) NSArray *filteredABList;


@property (nonatomic, retain) UISearchDisplayController *sdc;
@end

@implementation DFPeoplePickerViewController
@synthesize addressBook = _addressBook;


- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts
{
  self = [self init];
  if (self) {
    _suggestedPeanutContacts = suggestedPeanutContacts;
  }
  return self;
}

- (instancetype)init
{
  self = [super initWithNibName:@"DFPeoplePickerViewController" bundle:nil];
  if (self) {
    [self loadUnfilteredArrays];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureTableView];
  [self configureSearch];
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection
{
  _allowsMultipleSelection = allowsMultipleSelection;
  if (allowsMultipleSelection) {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithTitle:@"Send"
                                              style:UIBarButtonItemStylePlain
                                              target:self action:@selector(doneButtonPressed:)];
  }
}

- (void)loadUnfilteredArrays
{
  self.suggestedList = [NSArray arrayWithArray:self.suggestedPeanutContacts];
  self.onStrandList = @[]; // TODO fill in when available from server
  if (!self.ABList) {
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
      self.ABList = [self abSearchResultsForString:nil];
    }
  }
  self.unfilteredSections = @[self.ABList, @[@""]];
  self.unfilteredSectionTitles = @[@"Contacts"];
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

- (void)configureSearch
{
  UISearchBar *searchBar = [[UISearchBar alloc] init];
  searchBar.delegate = self;
  self.sdc = [[UISearchDisplayController alloc]
                                    initWithSearchBar:searchBar
                                    contentsController:self];
  self.sdc.searchResultsDataSource = self;
  self.sdc.searchResultsDelegate = self;
  self.tableView.tableHeaderView = searchBar;
}

- (NSArray *)selectedPeanutContacts
{
  return self.selectedContacts;
}

#pragma mark - UISearchDisplayController Delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
  [self updateSearchResults];
  if ([self.delegate respondsToSelector:@selector(pickerController:textDidChange:)]) {
    [self.delegate pickerController:self textDidChange:searchText];
  }
}

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
  self.isSearching = YES;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller
{
  self.isSearching = NO;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
  return YES;
}

- (void)updateSearchResults
{
  NSString *searchText = self.searchDisplayController.searchBar.text;
  
  if ([searchText isNotEmpty]) {
    NSMutableArray *sectionTitles = [NSMutableArray new];
    NSMutableArray *sections = [NSMutableArray new];
    
    self.textNumberString = [self textNumberStringForString:searchText];
    if (self.textNumberString) {
      [sectionTitles addObject:@"Text Number"];
      [sections addObject:@[self.textNumberString]];
    }
    
    NSPredicate *nameFilterPredicate = [NSPredicate predicateWithFormat:@"name ==[c] %@", searchText];
    self.filteredSuggestedList = [self.suggestedList filteredArrayUsingPredicate:nameFilterPredicate];
    if (self.filteredSuggestedList.count > 0) {
      [sectionTitles addObject:@"Suggestions"];
      [sections addObject:self.filteredSuggestedList];
    }
    
    self.filteredOnStrandList = [self.suggestedList filteredArrayUsingPredicate:nameFilterPredicate];
    if (self.filteredOnStrandList.count > 0) {
      [sectionTitles addObject:@"On Strand"];
      [sections addObject:self.filteredOnStrandList];
    }
    
    self.filteredABList = @[];
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
      self.filteredABList = [self abSearchResultsForString:searchText];
    }
    [sectionTitles addObject:@"Contacts"];
    [sections addObject:self.filteredABList];
    
    
    self.filteredSections = sections;
    self.filteredSectionTitles = sectionTitles;
  }
}

- (NSArray *)abSearchResultsForString:(NSString *)string
{
  if (ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) return @[];
  
  NSMutableArray *results = [NSMutableArray new];

  NSArray *people;
  if ([string isNotEmpty] ) {
    people = [self.addressBook peopleWithName:string];
  } else {
    people = [self.addressBook peopleOrderedByFirstName];
  }
  for (RHPerson *person in people) {
    for (int i = 0; i < person.phoneNumbers.values.count; i++) {
      DFPeanutContact *contact = [[DFPeanutContact alloc] init];
      contact.name = person.name;
      contact.phone_number = [person.phoneNumbers valueAtIndex:i];
      contact.phone_type = [person.phoneNumbers localizedLabelAtIndex:i];
      [results addObject:contact];
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
  NSInteger result = 1;
  
  if (tableView == self.tableView) {
    result += (self.suggestedList.count > 0);
    result += (self.onStrandList.count > 0);
  } else {
    //search results table view
    result += (self.filteredSuggestedList.count > 0);
    result += (self.filteredOnStrandList.count > 0);
    result += [self.textNumberString isNotEmpty];
  }
  
  return result;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (tableView == self.tableView) {
    return self.unfilteredSectionTitles[section];
  } else {
    return self.filteredSectionTitles[section];
  }
  return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return 30.0;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  NSArray *sectionArray;
  
  if (tableView == self.tableView) {
    sectionArray = self.unfilteredSections[section];
  } else {
    sectionArray = self.filteredSections[section];
  }
  
  return MAX(1, sectionArray.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  
  if (!object) {
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined) {
      cell = [self.tableView dequeueReusableCellWithIdentifier:@"noContacts"];
    } else {
      cell = [self.tableView dequeueReusableCellWithIdentifier:@"noResults"];
    }
    return cell;
  }
  
  if ([[object class] isSubclassOfClass:[DFPeanutContact class]]) {
    // all of these sections have cells for peanut users
      cell = [self cellForPeanutContact:(DFPeanutContact *)object indexPath:indexPath];
  } else if ([[object class] isSubclassOfClass:[NSString class]]) {
    cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.textLabel.text = [NSString stringWithFormat:@"Text %@", object];
    cell.imageView.image = [UIImage imageNamed:@"SMSTableCellIcon"];
  }

  return cell;
}

- (id)objectForIndexPath:(NSIndexPath *)indexPath tableView:(UITableView *)tableView
{
  NSArray *resultsArray;
  if (tableView != self.tableView) {
    resultsArray = self.filteredSections[indexPath.section];
  } else {
    resultsArray = self.unfilteredSections[indexPath.section];
  }
  
  id object = nil;
  if (indexPath.row < resultsArray.count) {
    object = resultsArray[indexPath.row];
  }
  return object;
}

- (UITableViewCell *)cellForPeanutContact:(DFPeanutContact *)peanutContact
                                indexPath:(NSIndexPath *)indexPath
{
  if (peanutContact.user) {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.textLabel.text = peanutContact.name;
    return cell;
  } else {
    DFABResultTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"abResult"];
    cell.titleLabel.text = peanutContact.name;
    cell.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@",
                          peanutContact.phone_type,
                          peanutContact.phone_number];
    return cell;
  }
  return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
 
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  if (object) return 44.0;
  
  return 91.0;
}

#pragma mark - Action Responses
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//  DFPeanutContact *selectedContact;
//  if (indexPath.section == 0 && self.abSearchResults.count > 0) {
//    NSDictionary *resultDict = self.abSearchResults[indexPath.row];
//    RHPerson *person = resultDict[@"person"];
//    int phoneIndex = [resultDict[@"index"] intValue];
//    selectedContact = [self contactForName:person.name number:[person.phoneNumbers valueAtIndex:phoneIndex]];
//  } else if (indexPath.section == 1 && self.textNumberString) {
//    selectedContact = [self contactForName:@"" number:self.textNumberString];
//  } else if (indexPath.section == 0 && ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) {
//    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
//    if (status == kABAuthorizationStatusNotDetermined) {
//      [self askForContactsPermission];
//    } else {
//      [self showContactsDeniedAlert];
//    }
//  }
//  
//  if (selectedContact) {
//    if (self.allowsMultipleSelection) {
//      [self.selectedContacts addObject:selectedContact];
//      [self updateSearchResults];
//      [self.tableView reloadData];
//      if ([self.delegate respondsToSelector:@selector(pickerController:pickedContactsDidChange:)]){
//        [self.delegate pickerController:self pickedContactsDidChange:self.selectedContacts];
//      }
//    } else {
//      if ([self.delegate respondsToSelector:@selector(pickerController:pickedContactsDidChange:)]){
//        [self.delegate pickerController:self pickedContactsDidChange:@[selectedContact]];
//      }
//      
//      //didChange is optional, didFinish is not so no need to check for responds to select
//      [self.delegate pickerController:self didFinishWithPickedContacts:@[selectedContact]];
//    }
//  }
  
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

- (void)doneButtonPressed:(id)sender
{
  [self.delegate pickerController:self didFinishWithPickedContacts:self.selectedPeanutContacts];
}

#pragma mark - Contacts Permission

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
