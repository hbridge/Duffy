//
//  DFContactsViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFContactsViewController.h"
#import <AddressBook/AddressBook.h>
#import "DFContactSyncManager.h"
#import "DFDefaultsStore.h"
#import "DFAnalytics.h"
#import "UIAlertView+DFHelpers.h"
#import "DFAddContactViewController.h"
#import "DFContactsStore.h"
#import "SVProgressHUD.h"
#import "DFLocationPermissionViewController.h"

@interface DFContactsViewController ()

@property (nonatomic, retain) DFAddContactViewController *addContactController;
@property (nonatomic, retain) NSArray *manualContacts;

@end

@implementation DFContactsViewController

- (instancetype)init
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.navigationItem.title = @"Find Friends";
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  self.manualContacts = [[DFContactsStore sharedStore] allContacts];
  if ([self canUserProceed] && self.navigationItem.rightBarButtonItem == nil) {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                              target:self
                                              action:@selector(showNextStep)];
  }
  [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self
          appearedWithParameters:@{@"showAsNUXStep": @(self.showAsNUXStep)}];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [[DFContactSyncManager sharedManager] sync];
}


- (BOOL)canUserProceed
{
  return (self.showAsNUXStep &&
          (self.manualContacts.count > 0
           || ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
          );
}

#pragma mark - Table View Delegate/Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == 0) return @"Add Friends";
  if (section == 1) return @"Manually Entered";
  
  return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
  if (section == 0) return @"Strand determines who your friends are based on names"
                           " and phone numbers in your address book.";
  
  return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0) return 2;
  if (section == 1) return self.manualContacts.count;
  
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell"];
  if (indexPath.section == 0) {
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (indexPath.row == 0) {
      if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusDenied) {
        cell.textLabel.text = @"Import Contacts Denied";
        cell.textLabel.textColor = [UIColor redColor];
      } else {
        cell.textLabel.text = @"Import Contacts";
        cell.textLabel.textColor = [UIColor blackColor];
      }
    }
    if (indexPath.row == 1) cell.textLabel.text = @"Enter Manually";
  } else if (indexPath.section == 1) {
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    DFContact *contact = self.manualContacts[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)",contact.name, contact.phoneNumber];
  }
  
  return cell;
}

#pragma mark - Action Handlers

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 0) {
    if (indexPath.row == 0) [self importContactsPressed];
    if (indexPath.row == 1) [self enterManuallyPressed];
  }
  
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)importContactsPressed
{
  if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusDenied) {
    [UIAlertView showSimpleAlertWithTitle:@"Enable Contacts"
                            formatMessage:@"Please go to Settings > Privacy > Contacts and turn on Strand."];
     return;
  }
  
  CFErrorRef error;
  ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, &error);
  ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef error) {
    if (granted) {
      [[DFContactSyncManager sharedManager] sync];
      [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionContacts];
      [[DFContactSyncManager sharedManager] sync];
      dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showSuccessWithStatus:@"Success!"];
      });
      if (self.canUserProceed) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [self showNextStep];
        });
      }
    } else {
      [DFDefaultsStore setState:DFPermissionStateDenied forPermission:DFPermissionContacts];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
      });
    }
  });
}

- (void)enterManuallyPressed
{
  DFAddContactViewController *addContactViewController = [[DFAddContactViewController alloc] init];
  [self.navigationController pushViewController:addContactViewController animated:YES];
}


- (void)showNextStep
{
  [DFAnalytics logSetupContactsCompletedWithABPermission:ABAddressBookGetAuthorizationStatus()
                                        numAddedManually:self.manualContacts.count];
  DFLocationPermissionViewController *lvc = [[DFLocationPermissionViewController alloc] init];
  [self.navigationController setViewControllers:@[lvc] animated:YES];
}

@end
