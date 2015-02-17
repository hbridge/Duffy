//
//  DFContactDataManager.m
//  Strand
//
//  Created by Derek Parham on 11/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFContactDataManager.h"
#import <RHAddressBook/AddressBook.h>
#import "DFPeanutFeedDataManager.h"
#import "DFPhoneNumberUtils.h"
#import "DFContactSyncManager.h"
#import "DFPeanutContact.h"

@interface DFContactDataManager ()

@property (nonatomic, retain) RHAddressBook *addressBook;
@property (nonatomic, retain) NSMutableDictionary *phoneNumberToPersonCache;

@end

@implementation DFContactDataManager

@synthesize phoneNumberToPersonCache = _phoneNumberToPersonCache;
@synthesize addressBook = _addressBook;

static DFContactDataManager *defaultManager;
+ (DFContactDataManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.addressBook = [[RHAddressBook alloc] init];
    [self refreshCacheWithCompletion:nil];
  }
  return self;
}

- (void)refreshCacheWithCompletion:(DFVoidBlock)completion
{
  dispatch_async(dispatch_get_main_queue(), ^{
    _phoneNumberToPersonCache = [NSMutableDictionary new];
    for (RHPerson *person in [self.addressBook people]) {
      RHMultiStringValue *phoneMultiValue = [person phoneNumbers];
      for (int x = 0; x < phoneMultiValue.count; x++) {
        NSString *rawPhoneNumber = [[phoneMultiValue valueAtIndex:x] description];
        NSString *phoneNumber =[DFPhoneNumberUtils normalizePhoneNumber:rawPhoneNumber];
        if (![_phoneNumberToPersonCache objectForKey:phoneNumber]) {
          [_phoneNumberToPersonCache setObject:[NSMutableArray new] forKey:phoneNumber];
        }
        
        [[_phoneNumberToPersonCache objectForKey:phoneNumber] addObject:person];
      }
    }
    if (completion) completion();
  });
}


- (NSString *)localNameFromPhoneNumber:(NSString *)phoneNumber
{
  RHPerson *person = [self personFromPhoneNumber:phoneNumber];
  if (person) {
    return [person name];
  }
  return nil;
}

- (RHPerson *)personFromPhoneNumber:(NSString *)phoneNumber
{
  if ([self.phoneNumberToPersonCache objectForKey:phoneNumber]) {
    return [[self.phoneNumberToPersonCache objectForKey:phoneNumber] firstObject];
  }
  
  return nil;
}

- (NSArray *)allPeanutContacts
{
  return [self peanutContactSearchResultsForString:nil];
}

- (NSArray *)peanutContactSearchResultsForString:(NSString *)string
{
  if ([DFContactSyncManager contactsPermissionStatus] != kABAuthorizationStatusAuthorized) return @[];
  
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

- (RHAddressBook *)addressBook
{
  if (!_addressBook) _addressBook = [[RHAddressBook alloc] init];
  return _addressBook;
}

@end
