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
#import "DFPersonSelectionTableViewCell.h"
#import "UINib+DFHelpers.h"
#import "DFStrandConstants.h"


@interface DFPeoplePickerViewController ()

@property (readonly, nonatomic, retain) RHAddressBook *addressBook;
@property (nonatomic, retain) NSMutableArray *unfilteredSectionTitles;
@property (nonatomic, retain) NSMutableArray *unfilteredSections;
@property (nonatomic, retain) NSArray *suggestedList;
@property (nonatomic, retain) NSArray *onStrandList;
@property (nonatomic, retain) NSArray *ABList;

@property (nonatomic, retain) UISearchDisplayController *sdc;
@property (nonatomic, retain) NSArray *filteredSectionTitles;
@property (nonatomic, retain) NSArray *filteredSections;
@property (nonatomic, retain) NSArray *filteredSuggestedList;
@property (nonatomic, retain) NSArray *filteredOnStrandList;
@property (nonatomic, retain) NSArray *filteredABList;

@property (nonatomic, retain) NSMutableArray *manualNumbersList;
@property (nonatomic, retain) NSMutableArray *selectedContacts;

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
    self.selectedContacts = [NSMutableArray new];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self loadUnfilteredArrays];
  [self configureTableView];
  [self configureSearch];
  [self configureNav];
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
  
  self.tableView.allowsMultipleSelection = allowsMultipleSelection;
}

- (void)loadUnfilteredArrays
{
  NSMutableArray *unfilteredSectionTitles = [NSMutableArray new];
  NSMutableArray *unfilteredSections = [NSMutableArray new];
  
  if (self.suggestedPeanutContacts.count > 0) {
    [unfilteredSectionTitles addObject:@"Suggestions"];
    self.suggestedList = self.suggestedPeanutContacts;
    [unfilteredSections addObject:self.suggestedList];
    [self.selectedContacts addObjectsFromArray:self.suggestedList];
  }
  
  NSArray *onStrandArray = @[];
  if (onStrandArray.count > 0) {// TODO fill in when available from server
    [unfilteredSectionTitles addObject:@"On Strand"];
    self.onStrandList = onStrandArray;
    [unfilteredSections addObject:self.onStrandList];
  }

  if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
    [unfilteredSectionTitles addObject:@"Contacts"];
    self.ABList = [self abSearchResultsForString:nil];
    [unfilteredSections addObject:self.ABList];
  }
  
  self.unfilteredSections = unfilteredSections;
  self.unfilteredSectionTitles = unfilteredSectionTitles;
}

- (void)configureTableView
{
  // account for the gap caused by not having a navbar shadow image
  UIEdgeInsets insets = self.tableView.contentInset;
  insets.top = insets.top - 1;
  self.tableView.contentInset = insets;
  
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
  [self.tableView registerNib:[UINib nibForClass:[DFPersonSelectionTableViewCell class]]
       forCellReuseIdentifier:@"nonUser"];
  [self.tableView registerNib:[UINib nibForClass:[DFPersonSelectionTableViewCell class]]
       forCellReuseIdentifier:@"user"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNoContactsTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"noContacts"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFNoResultsTableViewCell" bundle:nil]
       forCellReuseIdentifier:@"noResults"];
  if (self.allowsMultipleSelection) {
    self.tableView.allowsMultipleSelection = YES;
  }
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

- (void)configureNav
{
  int count = (int)self.selectedContacts.count;
  if (count > 0) {
    self.navigationItem.title = [NSString stringWithFormat:@"%d Selected", count];
    self.navigationItem.rightBarButtonItem.enabled = YES;
  } else {
    self.navigationItem.title = @"None Selected";
    self.navigationItem.rightBarButtonItem.enabled = NO;
  }
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
    
    NSPredicate *nameFilterPredicate = [NSPredicate predicateWithFormat:@"name BEGINSWITH[cd] %@", searchText];
    self.filteredSuggestedList = [self.suggestedList filteredArrayUsingPredicate:nameFilterPredicate];
    if (self.filteredSuggestedList.count > 0) {
      [sectionTitles addObject:@"Suggestions"];
      [sections addObject:self.filteredSuggestedList];
    }
    
    self.filteredOnStrandList = [self.onStrandList filteredArrayUsingPredicate:nameFilterPredicate];
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
    return self.unfilteredSections.count;
  } else {
    return self.filteredSections.count;
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
  
  if ([self.selectedContacts containsObject:object]) {
    [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
  }
  
  if (!cell) [NSException raise:@"Cell is Nil" format:@"Returning nil cell for object: %@.", object];

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
    DFPersonSelectionTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"user"];
    [cell configureWithCellStyle:DFPersonSelectionTableViewCellStyleStrandUser];
    cell.nameLabel.text = peanutContact.name;
    cell.profilePhotoStackView.names = @[peanutContact.name];
    return cell;
  } else {
    DFPersonSelectionTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"nonUser"];
    [cell configureWithCellStyle:DFPersonSelectionTableViewCellStyleNonUser];
    cell.nameLabel.text = peanutContact.name;
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
  if (object) return 54.0;
  
  return 91.0;
}

#pragma mark - Action Responses
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  DDLogVerbose(@"tapped object:%@", object);
  
  if ([[object class] isSubclassOfClass:[DFPeanutContact class]]) {
    // all of these sections have cells for peanut users
    [self.selectedContacts addObject:object];
    if ([self.delegate respondsToSelector:@selector(pickerController:pickedContactsDidChange:)]){
      [self.delegate pickerController:self pickedContactsDidChange:self.selectedContacts];
    }
  } else if ([[object class] isSubclassOfClass:[NSString class]]) {
    [self textNumberRowTapped:object];
    if ([self.delegate respondsToSelector:@selector(pickerController:pickedContactsDidChange:)]){
      [self.delegate pickerController:self pickedContactsDidChange:self.selectedContacts];
    }
  } else {
    if (ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) {
      ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
      if (status == kABAuthorizationStatusNotDetermined) {
        [self askForContactsPermission];
      } else {
        [self showContactsDeniedAlert];
      }
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
  } 

  DDLogVerbose(@"new selected contacts:%@", self.selectedContacts);
  
  // if this happened in the search tableview, we have to reload the regular table view in the bg
  if (tableView != self.tableView) [self.tableView reloadData];
  
  [self configureNav];
}

- (void)textNumberRowTapped:(NSString *)phoneNumber
{
  DFPeanutContact *textNumberContact = [[DFPeanutContact alloc] init];
  textNumberContact.phone_number = phoneNumber;
  textNumberContact.name = phoneNumber;
  textNumberContact.phone_type = @"unknown";
  if (!self.manualNumbersList) {
    self.manualNumbersList = [NSMutableArray new];
    [self.unfilteredSections insertObject:self.manualNumbersList atIndex:1];
    [self.unfilteredSectionTitles insertObject:@"Phone Numbers" atIndex:1];
  }
  [self.manualNumbersList addObject:textNumberContact];
  [self.selectedContacts addObject:textNumberContact];
  self.searchDisplayController.searchBar.text = @"";
  //    [self.searchDisplayController.searchBar resignFirstResponder];
  [self.searchDisplayController setActive:NO animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  DDLogVerbose(@"tapped object:%@", object);
  if ([[object class] isSubclassOfClass:[DFPeanutContact class]]) {
    [self.selectedContacts removeObject:object];
    if ([self.delegate respondsToSelector:@selector(pickerController:pickedContactsDidChange:)]){
      [self.delegate pickerController:self pickedContactsDidChange:self.selectedContacts];
    }
  }
  
  // if this happened in the search tableview, we have to reload the regular table view in the bg
  if (tableView != self.tableView) [self.tableView reloadData];
  [self configureNav];
  
  DDLogVerbose(@"new selected contacts:%@", self.selectedContacts);
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
  [self.delegate pickerController:self
      didFinishWithPickedContacts:self.selectedPeanutContacts];
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
