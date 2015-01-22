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
    [self setSections:[self.class sectionsOfContacts]];
  }
  return self;
}

- (instancetype)initWithSuggestedPeanutUsers:(NSArray *)suggestedPeanutedUsers
{
  NSArray *peanutContacts = [suggestedPeanutedUsers arrayByMappingObjectsWithBlock:^id(id input) {
    DFPeanutContact *contact = [[DFPeanutContact alloc] initWithPeanutUser:input];
    return contact;
  }];
  self = [self initWithSuggestedPeanutContacts:peanutContacts];
  if (self) {
    
  }
  return self;
}

- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts
{
  return [self initWithSelectedPeanutContacts:suggestedPeanutContacts];
}

- (instancetype)initWithSuggestedPeanutContacts:(NSArray *)suggestedPeanutContacts
                    notSelectablePeanutContacts:(NSArray *)notSelectableContacts
                            notSelectableReason:(NSString *)notSelectableReason
{
  self = [self initWithSuggestedPeanutContacts:suggestedPeanutContacts];
  if (self) {
    self.notSelectableContacts = notSelectableContacts;
    self.notSelectableReason = notSelectableReason;
  }
  return self;
}


+ (NSArray *)sectionsOfContacts
{
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
  NSArray *contacts = [[DFContactDataManager sharedManager] allPeanutContacts];
  if (contacts.count > 0) {
    [sections addObject:[DFSection sectionWithTitle:ContactsSectionTitle object:nil rows:contacts]];
  }
  
  return sections;
}


@end
