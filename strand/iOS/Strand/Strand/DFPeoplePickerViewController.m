//
//  DFPeoplePickerController.m
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeoplePickerViewController.h"
#import "NSString+DFHelpers.h"
#import "DFDefaultsStore.h"
#import "UIAlertView+DFHelpers.h"
#import "DFAnalytics.h"
#import "DFUser.h"
#import "DFPeanutUserObject.h"
#import "DFABResultTableViewCell.h"
#import "DFContactSyncManager.h"
#import "DFContactDataManager.h"
#import "DFPersonSelectionTableViewCell.h"
#import "UINib+DFHelpers.h"
#import "DFStrandConstants.h"
#import "DFPeanutFeedDataManager.h"
#import "NSArray+DFHelpers.h"
#import "DFSMSInviteStrandComposeViewController.h"
#import "DFSection.h"


@interface DFPeoplePickerViewController ()

@property (nonatomic, retain) NSArray *unfilteredSections;
@property (nonatomic, retain) NSArray *filteredSections;
@property (nonatomic, retain) UISearchDisplayController *sdc;

@property (nonatomic, retain) DFSection *selectedSection;
@property (nonatomic) BOOL hideStatusBar;


@end

@implementation DFPeoplePickerViewController
@synthesize doneButtonActionText = _doneButtonActionText;


NSString *const UsersThatAddedYouSectionTitle = @"People who Added You";

- (instancetype)init
{
  self = [super initWithNibName:@"DFPeoplePickerViewController" bundle:nil];
  if (self) {
    self.disableContactsUpsell = YES;
    self.selectedContacts = [NSMutableArray new];
    [self configureNav];
  }
  return self;
}

- (instancetype)initWithSections:(NSArray *)sections
{
  self = [self init];
  if (self) {
    self.unfilteredSections = sections;
  }
  return self;
}

- (void)setSections:(NSArray *)sections
{
  self.unfilteredSections = sections;
  [self.tableView reloadData];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureTableView];
  [self configureSearch];
  [self selectionUpdatedSilently:YES];
  [self configureNoResultsView];
}

- (void)configureNoResultsView
{
  if ([DFContactSyncManager contactsPermissionStatus] != kABAuthorizationStatusAuthorized
      && self.unfilteredSections.count == 0
      && !self.disableContactsUpsell) {
    self.noResultsView = [UINib instantiateViewWithClass:[DFNoTableItemsView class]];
    self.noResultsView.titleLabel.text = @"Show Contacts";
    self.noResultsView.subtitleLabel.text = @"Grant contacts permission to show results from your Contacts.";
    [self.noResultsView.button setTitle:@"Grant Permission" forState:UIControlStateNormal];
    DFPeoplePickerViewController __weak *weakSelf = self;
    self.noResultsView.buttonHandler = ^{[weakSelf askForContactsPermission];};
    self.noResultsView.button.hidden = NO;
    [self.noResultsView setSuperView:self.tableView];
  } else {
    [self.noResultsView removeFromSuperview];
    self.noResultsView = nil;
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFSMSInviteStrandComposeViewController warmUpSMSComposer];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)configureNav
{
  self.navigationItem.title = @"Select People";
}

- (void)setPrefersStatusBarHidden:(BOOL)prefersStatusBarHidden
{
  _hideStatusBar = prefersStatusBarHidden;
  [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersStatusBarHidden
{
  return self.hideStatusBar;
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection
{
  _allowsMultipleSelection = allowsMultipleSelection;
  if (allowsMultipleSelection) {
    self.doneButtonWrapper.hidden = NO;
  } else {
    self.doneButtonWrapper.hidden = YES;
  }
  
  self.tableView.allowsMultipleSelection = allowsMultipleSelection;
}


- (void)configureTableView
{
  // account for the gap caused by not having a navbar shadow image
  UIEdgeInsets insets = self.tableView.contentInset;
  insets.top = insets.top - 1;
  insets.bottom = self.doneButtonWrapper.frame.size.height;
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
  self.searchBar.delegate = self;

  self.sdc = [[UISearchDisplayController alloc]
                                    initWithSearchBar:self.searchBar
                                    contentsController:self];
  self.sdc.searchResultsDataSource = self;
  self.sdc.searchResultsDelegate = self;
  self.sdc.delegate = self;
}

- (void)setDoneButtonActionText:(NSString *)doneButtonActionText
{
  _doneButtonActionText = doneButtonActionText;
  [self selectionUpdatedSilently:YES];
}

- (NSString *)doneButtonActionText
{
  if (!_doneButtonActionText) return @"Send to";
  return _doneButtonActionText;
}

- (void)setSelectedPeanutContacts:(NSArray *)selectedPeanutContacts
{
  _selectedContacts = selectedPeanutContacts;
  [self selectionUpdatedSilently:YES];
}

- (void)selectionUpdatedSilently:(BOOL)silently
{
  int count = (int)self.selectedContacts.count;
  NSString *buttonTitle;
  if (count > 1) {
    //self.navigationItem.title = [NSString stringWithFormat:@"%d People Selected", count];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    buttonTitle = [NSString stringWithFormat:@"%@ %d People", self.doneButtonActionText, count];
    self.doneButton.enabled = YES;
    self.doneButtonWrapper.hidden = NO;
  } else if (count == 1) {
    //self.navigationItem.title = [NSString stringWithFormat:@"%d Person Selected", count];
    self.navigationItem.rightBarButtonItem.enabled = YES;
    buttonTitle = [NSString stringWithFormat:@"%@ 1 Person", self.doneButtonActionText];
    self.doneButton.enabled = YES;
    self.doneButtonWrapper.hidden = NO;
  } else {
    if ([self hasUnfilteredResults]) {
      self.doneButtonWrapper.hidden = NO;
    } else {
      self.doneButtonWrapper.hidden = YES;
    }
    buttonTitle = @"No One Selected";
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.doneButton.enabled = NO;
  }
  [self.doneButton setTitle:buttonTitle forState:UIControlStateNormal];
  
  
  if (!self.selectedSection) {
    self.selectedSection = [DFSection sectionWithTitle:@"Selected"
                                                object:nil
                                                  rows:self.selectedContacts];
  }
  self.selectedSection.rows = self.selectedContacts;
  if (self.selectedContacts.count > 0 && ![self.unfilteredSections containsObject:self.selectedSection]) {
    self.unfilteredSections = [@[self.selectedSection] arrayByAddingObjectsFromArray:self.unfilteredSections];
  } else if (self.selectedContacts.count == 0) {
    self.unfilteredSections = [self.unfilteredSections arrayByRemovingObject:self.selectedSection];
  }
  
  if (!silently
      && [self.delegate respondsToSelector:@selector(pickerController:pickedContactsDidChange:)]){
    [self.delegate pickerController:self pickedContactsDidChange:self.selectedContacts];
  }
  
  [self.tableView reloadData];
}

- (BOOL)hasUnfilteredResults
{
  for (DFSection *section in self.unfilteredSections) {
    if (section.rows.count > 0) return YES;
  }
  
  return NO;
}

#pragma mark - UISearchDisplayController Delegate

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller
{
  self.hideStatusBar = YES;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
  self.hideStatusBar = NO;
}

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
    NSMutableArray *filteredSections = [NSMutableArray new];
    self.textNumberString = [self textNumberStringForString:searchText];
    if (self.textNumberString) {
      [filteredSections addObject:[DFSection sectionWithTitle:@"Phone Number"
                                                       object:nil
                                                         rows:@[self.textNumberString]]];
    }
    
    NSPredicate *nameFilterPredicate = [NSPredicate predicateWithFormat:@"name BEGINSWITH[cd] %@", searchText];
    for (DFSection *section in self.unfilteredSections) {
      NSArray *peanutContacts = section.rows;
      NSArray *filteredContacts = [peanutContacts filteredArrayUsingPredicate:nameFilterPredicate];
      if (filteredContacts.count > 0) {
        [filteredSections addObject:[DFSection sectionWithTitle:section.title
                                                         object:nil
                                                           rows:filteredContacts]];
      }
    }
    
    if ([searchText isNotEmpty] && filteredSections.count == 0) {
      [filteredSections addObject:[DFSection sectionWithTitle:@"No Results" object:nil rows:@[[NSNull new]]]];
    }
    
    self.filteredSections = filteredSections;
  }
}

- (NSString *)textNumberStringForString:(NSString *)string
{
  static NSRegularExpression *phoneNumberRegex = nil;
  if (!phoneNumberRegex) {
    NSError *error;
    phoneNumberRegex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+$" options:0 error:&error];
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
    if (self.unfilteredSections.count > 0) result = self.unfilteredSections.count;
  } else {
    if (self.filteredSections.count > 0) result = self.filteredSections.count;
  }
  
  return result;
}

- (DFSection *)sectionForIndex:(NSUInteger)sectionIndex inTableView:(UITableView *)tableView
{
  NSArray *sections;
  if (tableView == self.tableView) {
    sections = self.unfilteredSections;
  } else {
    sections = self.filteredSections;
  }
  
  DFSection *section = sections[sectionIndex];
  return section;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)sectionIndex
{
  return [[self sectionForIndex:sectionIndex inTableView:tableView] title];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return 30.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
  DFSection *section = [self sectionForIndex:sectionIndex inTableView:tableView];
  return section.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  
  if (!object || object == [NSNull null]) {
    if ([DFContactSyncManager contactsPermissionStatus] == kABAuthorizationStatusNotDetermined
        && !self.disableContactsUpsell) {
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
  DFSection *section = [self sectionForIndex:indexPath.section inTableView:tableView];
  return section.rows[indexPath.row];
}

- (BOOL)isContactSelectable:(DFPeanutContact *)contact
{
  for (DFPeanutContact *notSelectableContact in self.notSelectableContacts) {
    if ([notSelectableContact.user isEqual:contact.user]) return NO;
  }
  return YES;
}

- (BOOL)isUserSelectable:(DFPeanutUserObject *)user
{
  for (DFPeanutContact *notSelectableContact in self.notSelectableContacts) {
    if ([notSelectableContact.user isEqual:user]) return NO;
  }
  return YES;
}


- (UITableViewCell *)cellForPeanutContact:(DFPeanutContact *)peanutContact
                                indexPath:(NSIndexPath *)indexPath
{
  DFPersonSelectionTableViewCell *cell;
  if (peanutContact.user) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithID:peanutContact.user.longLongValue];
    return [self cellForPeanutUser:user indexPath:indexPath];
  } else {
    DFPersonSelectionTableViewCell *nonUserCell = [self.tableView dequeueReusableCellWithIdentifier:@"nonUser"];
    [nonUserCell configureWithCellStyle:DFPersonSelectionTableViewCellStyleSubtitle];
    nonUserCell.nameLabel.text = peanutContact.name;
    nonUserCell.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@",
                          peanutContact.phone_type,
                          peanutContact.phone_number];
    cell = nonUserCell;
  }
  
  [self configureCell:cell isSelectable:[self isContactSelectable:peanutContact]];
  
  return cell;
}

- (UITableViewCell *)cellForPeanutUser:(DFPeanutUserObject *)peanutUser
                                indexPath:(NSIndexPath *)indexPath
{
  DFPersonSelectionTableViewCell *userCell = [self.tableView dequeueReusableCellWithIdentifier:@"user"];
  [userCell configureWithCellStyle:DFPersonSelectionTableViewCellStyleStrandUser | DFPersonSelectionTableViewCellStyleRightLabel];
  userCell.nameLabel.text = peanutUser.fullName;
  userCell.profilePhotoStackView.peanutUsers = @[peanutUser];

  [self configureCell:userCell isSelectable:[self isUserSelectable:peanutUser]];
  
  return userCell;
}

- (void)configureCell:(DFPersonSelectionTableViewCell *)cell isSelectable:(BOOL)isSelectable
{
  if (isSelectable) {
    cell.userInteractionEnabled = YES;
    cell.nameLabel.textColor = [UIColor blackColor];
    cell.rightLabel.text = @"";
  } else {
    cell.userInteractionEnabled = NO;
    cell.nameLabel.textColor = [UIColor lightGrayColor];
    cell.rightLabel.text = self.notSelectableReason;
  }
  
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
 
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  if (object) return 54.0;
  
  return 105;
}

#pragma mark - Action Responses
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  DDLogVerbose(@"tapped object:%@", object);
  BOOL contactSelected = NO;
  
  if ([[object class] isSubclassOfClass:[DFPeanutContact class]]) {
    [self contactRowSelected:object atIndexPath:indexPath];
    contactSelected = YES;
  } else if ([[object class] isSubclassOfClass:[NSString class]]) {
    [self textNumberRowSelected:object];
    contactSelected = YES;
  } else {
    ABAuthorizationStatus status = [DFContactSyncManager contactsPermissionStatus];
    if (status != kABAuthorizationStatusAuthorized) {
      if (status == kABAuthorizationStatusNotDetermined) {
        [self askForContactsPermission];
      } else {
        [self showContactsDeniedAlert];
      }
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
  } 

  DDLogVerbose(@"new selected contacts:%@", self.selectedContacts);
  
  if (contactSelected) {
    if ([self.delegate respondsToSelector:@selector(pickerController:pickedContactsDidChange:)]){
      [self.delegate pickerController:self pickedContactsDidChange:self.selectedContacts];
    }
    
    // if this happened in the search tableview and there was a contact object selected,
    // we have to reload the regular table view in the bg
    if (tableView != self.tableView) {
      [self.tableView reloadData];
      [self.sdc setActive:NO animated:NO];
    }
    
    [self selectionUpdatedSilently:NO];
  }
}

- (void)contactRowSelected:(DFPeanutContact *)contact atIndexPath:(NSIndexPath *)indexPath
{
  self.selectedContacts = [self.selectedContacts arrayByAddingObject:contact];
  [self selectionUpdatedSilently:NO];
}

- (void)textNumberRowSelected:(NSString *)phoneNumber
{
  DFPeanutContact *textNumberContact = [[DFPeanutContact alloc] init];
  textNumberContact.phone_number = phoneNumber;
  textNumberContact.name = phoneNumber;
  textNumberContact.phone_type = @"text";
  
  self.selectedContacts = [self.selectedContacts arrayByAddingObject:textNumberContact];
  self.searchDisplayController.searchBar.text = @"";
  [self.searchDisplayController setActive:NO animated:YES];
  [self selectionUpdatedSilently:NO];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
  id object = [self objectForIndexPath:indexPath tableView:tableView];
  DDLogVerbose(@"tapped object:%@", object);
  if ([[object class] isSubclassOfClass:[DFPeanutContact class]]) {
    self.selectedContacts = [self.selectedContacts arrayByRemovingObject:object];
    [self selectionUpdatedSilently:NO];
    DDLogVerbose(@"new selected contacts:%@", self.selectedContacts);
  }
  
  // if this happened in the search tableview, we have to reload the regular table view in the bg
  if (tableView != self.tableView) [self.tableView reloadData];
}

- (IBAction)doneButtonPressed:(id)sender
{
  [self.delegate pickerController:self
      didFinishWithPickedContacts:self.selectedContacts];
}

#pragma mark - Contacts Permission

- (void)askForContactsPermission
{
  DFPeoplePickerViewController __weak *weakSelf = self;
  [DFContactSyncManager askForContactsPermissionWithSuccess:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf configureNoResultsView];
      [weakSelf updateSearchResults];
      [weakSelf.tableView reloadData];
      [weakSelf.sdc.searchResultsTableView reloadData];
    });
  } failure:^(NSError *error) {
    
  }];
}

- (void)showContactsDeniedAlert
{
  [UIAlertView showSimpleAlertWithTitle:@"Contacts Denied"
                          formatMessage:@"Please go to Settings > Privacy > Contacts and change Strand to on."];
}



@end
