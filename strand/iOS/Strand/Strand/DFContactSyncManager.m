//
//  DFContactSyncManager.m
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFContactSyncManager.h"
#import <AddressBook/AddressBook.h>
#import "DFDefaultsStore.h"
#import "DFPeanutContactAdapter.h"
#import "DFPeanutContact.h"
#import "DFUser.h"

@implementation DFContactSyncManager

// We want the upload controller to be a singleton
static DFContactSyncManager *defaultManager;
+ (DFContactSyncManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
}

- (void)sync
{
  NSDate *lastSync = [DFDefaultsStore lastDateForAction:DFUserActionSyncContacts];
  if (!lastSync) lastSync = [NSDate dateWithTimeIntervalSince1970:0];
  [self syncWithLastSyncDate:lastSync];
}

- (void)forceSync
{
  [self syncWithLastSyncDate:[NSDate dateWithTimeIntervalSince1970:0]];
}

- (void)syncWithLastSyncDate:(NSDate *)lastSync
{
  [self peanutContactsFromABModifiedAfterDate:lastSync withCompletion:^(NSArray *peanutContacts) {
    if (peanutContacts.count == 0) {
      DDLogInfo(@"%@ no new contacts found.", [self.class description]);
      return;
    }
    DFPeanutContactAdapter *contactAdapter = [DFPeanutContactAdapter new];
    [contactAdapter postPeanutContacts:peanutContacts success:^(NSArray *peanutContacts) {
      DDLogInfo(@"Posting %d contacts succeeded.", (int)peanutContacts.count);
      [DFDefaultsStore setLastDate:[NSDate date] forAction:DFUserActionSyncContacts];
    } failure:^(NSError *error) {
      DDLogError(error.description);
    }];
  }];
}

- (void)peanutContactsFromABModifiedAfterDate:(NSDate *)minimumDate
                               withCompletion:(void(^)(NSArray *peanutContacts))completion
{
  DDLogInfo(@"%@ looking for contacts modified after %@...", [self.class description], minimumDate);
  NSMutableArray *peanutContacts = [NSMutableArray new];
  
  CFErrorRef error;
  ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
  ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if (granted) {
        // First time access has been granted, add all the user's contacts to array.
        CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(addressBook);
        
        for (CFIndex i = 0; i < CFArrayGetCount(people); i++) {
          ABRecordRef record = CFArrayGetValueAtIndex(people, i);
          NSDate *modifiedDate = (__bridge_transfer NSDate*) ABRecordCopyValue(record, kABPersonModificationDateProperty);
          if ([modifiedDate compare:minimumDate] != NSOrderedDescending) continue;
          
          //name
          NSString *firstName = (__bridge_transfer NSString*) ABRecordCopyValue(record,
                                                                                kABPersonFirstNameProperty);
          NSString *lastName = (__bridge_transfer NSString*) ABRecordCopyValue(record,
                                                                               kABPersonLastNameProperty);
          //phone numbers
          ABMultiValueRef phoneNumbers = ABRecordCopyValue(record, kABPersonPhoneProperty);
          for (CFIndex p_i = 0; p_i < ABMultiValueGetCount(phoneNumbers); p_i++) {
            NSString* phoneNumber = (__bridge_transfer NSString*) ABMultiValueCopyValueAtIndex(phoneNumbers, p_i);
            DFPeanutContact *peanutContact = [DFPeanutContact new];
            peanutContact.name = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
            peanutContact.user = @([[DFUser currentUser] userID]);
            peanutContact.phone_number = phoneNumber;
            [peanutContacts addObject:peanutContact];
          }
          
          CFRelease(phoneNumbers);
        }
        
        CFRelease(addressBook);
        CFRelease(people);
        
        completion(peanutContacts);
      } else {
        DDLogWarn(@"%@ cannot sync, access not granted.", [self.class description]);
      }
    });
  });
}



@end
