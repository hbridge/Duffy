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
    self.phoneNumberToPersonCache = [NSMutableDictionary new];
  }
  return self;
}

- (void)refreshCache
{
  _phoneNumberToPersonCache = nil;
  [self phoneNumberToPersonCache];
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


- (NSMutableDictionary *)phoneNumberToPersonCache
{
  if (!_phoneNumberToPersonCache) {
    _phoneNumberToPersonCache = [NSMutableDictionary new];
    for (RHPerson *person in [self.addressBook people]) {
      RHMultiStringValue *phoneMultiValue = [person phoneNumbers];
      for (int x = 0; x < phoneMultiValue.count; x++) {
        NSString *rawPhoneNumber = [[phoneMultiValue valueAtIndex:x] description];
        
        // Get phone number into the format of +15551234567
        NSString *phoneNumber = [[rawPhoneNumber componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
        if (![phoneNumber hasPrefix:@"1"]) {
          phoneNumber = [NSString stringWithFormat:@"1%@", phoneNumber];
        }
        phoneNumber = [NSString stringWithFormat:@"+%@", phoneNumber];
        
        if (![_phoneNumberToPersonCache objectForKey:phoneNumber]) {
          [_phoneNumberToPersonCache setObject:[NSMutableArray new] forKey:phoneNumber];
        }
        
        [[_phoneNumberToPersonCache objectForKey:phoneNumber] addObject:person];
      }
    }
  }
  return _phoneNumberToPersonCache;
}

- (RHAddressBook *)addressBook
{
  if (!_addressBook) _addressBook = [[RHAddressBook alloc] init];
  return _addressBook;
}

@end
