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

- (instancetype)initWithSelectedPeanutContacts:(NSArray *)selectedPeanutContacts
{
  self = [self init];
  if (self) {
    self.selectedContacts = selectedPeanutContacts;
  }
  return self;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self observeNotifications];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    [self setSections:sections];
    
    NSMutableArray *sectionsWithContacts = [sections mutableCopy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      DFSection *contactsSection = [DFPeoplePickerViewController allContactsSectionExcludingFriends:YES];
      dispatch_async(dispatch_get_main_queue(), ^{
        [sectionsWithContacts addObject:contactsSection];
        [self setSections:sectionsWithContacts];
      });
    });
  });
}


@end
