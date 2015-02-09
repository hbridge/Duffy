//
//  DFRecipientPickerViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/22/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFRecipientPickerViewController.h"
#import "DFSection.h"
#import "DFPeanutFeedDataManager.h"
#import "DFContactDataManager.h"
#import "DFNotificationSharedConstants.h"

NSString *const UserSectionTitle = @"Swap Friends";
NSString *const SuggestedSecitonTitle = @"Suggested";
NSString *const ContactsSectionTitle = @"Contacts";


@interface DFRecipientPickerViewController ()

@end

@implementation DFRecipientPickerViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self observeNotifications];
  }
  return self;
}

- (instancetype)initWithSelectedPeanutContacts:(NSArray *)selectedPeanutContacts
{
  self = [self init];
  if (self) {
    self.selectedContacts = selectedPeanutContacts;
  }
  return self;
}


- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reloadData)
                                               name:DFContactPermissionChangedNotificationName
                                             object:nil];
}

- (void)setSuggestedPeanutUsers:(NSArray *)peanutUsers
{
  NSArray *peanutContacts = [peanutUsers arrayByMappingObjectsWithBlock:^id(id input) {
    DFPeanutContact *contact = [[DFPeanutContact alloc] initWithPeanutUser:input];
    return contact;
  }];
  self.selectedContacts = peanutContacts;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self reloadData];
}


- (void)reloadData
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableArray *sections = [NSMutableArray new];
    NSArray *friendUsers = [[DFPeanutFeedDataManager sharedManager] friendsList];
    NSArray *friendContacts = [friendUsers arrayByMappingObjectsWithBlock:^id(id input) {
      return [[DFPeanutContact alloc] initWithPeanutUser:input];
    }];
    if (friendContacts.count > 0) {
      [sections addObject:[DFSection sectionWithTitle:UserSectionTitle
                                               object:nil
                                                 rows:friendContacts]];
    }
    [sections addObject:[DFPeoplePickerViewController allContactsSectionExcludingFriends:YES]];
    [self setSections:sections];
  });
}


@end
