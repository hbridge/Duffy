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
#import "DFContactsStore.h"
#import "DFAnalytics.h"
#import "UIAlertView+DFHelpers.h"

@interface DFContactSyncManager()

@property (atomic) BOOL isABSyncInProgress;
@property (atomic) BOOL isDFContactsSyncInProgress;

@end

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
  if (self.isABSyncInProgress || self.isDFContactsSyncInProgress) {
    DDLogVerbose(@"%@ sync requested but sync already in progress.  Skipping.", self.class);
    return;
  }
  if ([DFContactSyncManager contactsPermissionStatus] == kABAuthorizationStatusAuthorized) {
    NSDate *lastABSync = [DFDefaultsStore lastDateForAction:DFUserActionSyncContacts];
    if (!lastABSync) lastABSync = [NSDate dateWithTimeIntervalSince1970:0];
    [self syncABContactsWithLastSyncDate:lastABSync];
  }
  
  NSDate *lastDFContactSync = [DFDefaultsStore lastDateForAction:DFUserActionSyncManualContacts];
  if (!lastDFContactSync) lastDFContactSync = [NSDate dateWithTimeIntervalSince1970:0];
  [self syncDFContactsWithLastSyncDate:lastDFContactSync];
}

- (void)forceSync
{
  self.isABSyncInProgress = self.isDFContactsSyncInProgress = NO;
  [self syncABContactsWithLastSyncDate:[NSDate dateWithTimeIntervalSince1970:0]];
  [self syncDFContactsWithLastSyncDate:[NSDate dateWithTimeIntervalSince1970:0]];
}

- (void)syncABContactsWithLastSyncDate:(NSDate *)lastSync
{
  if (self.isABSyncInProgress) return;
  self.isABSyncInProgress = YES;

  DFPeanutContactAdapter *contactAdapter = [DFPeanutContactAdapter new];
  [self peanutContactsFromABModifiedAfterDate:lastSync withCompletion:^(NSArray *peanutContacts) {
    if (peanutContacts.count == 0) {
      DDLogInfo(@"%@ no new AB contacts found.", [self.class description]);
      self.isABSyncInProgress = NO;
      return;
    }
    [contactAdapter postPeanutContacts:peanutContacts success:^(NSArray *peanutContacts) {
      DDLogInfo(@"%@ posting %d AB contacts succeeded.", [self.class description], (int)peanutContacts.count);
      [DFDefaultsStore setLastDate:[NSDate date] forAction:DFUserActionSyncContacts];
      self.isABSyncInProgress = NO;
    } failure:^(NSError *error) {
      DDLogError(@"%@ posting AB contacts failed: %@", [self.class description], error.description);
      self.isABSyncInProgress = NO;
    }];
  }];
}

- (void)syncDFContactsWithLastSyncDate:(NSDate *)lastSync
{
  if (self.isDFContactsSyncInProgress) return;
  self.isDFContactsSyncInProgress = YES;
  
  DFPeanutContactAdapter *contactAdapter = [DFPeanutContactAdapter new];
  NSArray *manualContacts = [[DFContactsStore sharedStore] contactsModifiedAfterDate:lastSync];
  if (manualContacts.count == 0) {
    DDLogInfo(@"%@ no new manual contacts found.", [self.class description]);
    self.isDFContactsSyncInProgress = NO;
    return;
  }
  
  NSMutableArray *manualPeanutContacts = [NSMutableArray new];
  for (DFContact *contact in manualContacts) {
    DFPeanutContact *peanutContact = [[DFPeanutContact alloc] init];
    peanutContact.name = contact.name;
    peanutContact.phone_number = contact.phoneNumber;
    peanutContact.user = @([[DFUser currentUser] userID]);
    [manualPeanutContacts addObject:peanutContact];
  }
  [contactAdapter postPeanutContacts:manualPeanutContacts success:^(NSArray *peanutContacts) {
    DDLogInfo(@"%@ posting %d manual contacts succeeded.", [self.class description], (int)manualPeanutContacts.count);
    [DFDefaultsStore setLastDate:[NSDate date] forAction:DFUserActionSyncManualContacts];
    self.isDFContactsSyncInProgress = NO;
  } failure:^(NSError *error) {
    DDLogError(@"%@ posting manual contacts failed: %@", [self.class description], error.description);
    self.isDFContactsSyncInProgress = NO;
  }];
}

- (void)peanutContactsFromABModifiedAfterDate:(NSDate *)minimumDate
                               withCompletion:(void(^)(NSArray *peanutContacts))completion
{
  DDLogInfo(@"%@ looking for AB contacts modified after %@...", [self.class description], minimumDate);
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


+ (ABAuthorizationStatus)contactsPermissionStatus
{
#ifdef DEBUG
  DFPermissionStateType state = [DFDefaultsStore stateForPermission:DFPermissionContacts];
  if ([state isEqual:DFPermissionStateGranted]) {
    return kABAuthorizationStatusAuthorized;
  } else if ([state isEqual:DFPermissionStateDenied]) {
    return kABAuthorizationStatusDenied;
  } else {
    return kABAuthorizationStatusNotDetermined;
  }
#else
  return ABAddressBookGetAuthorizationStatus();
#endif
}

+ (void)askForContactsPermissionWithSuccess:(void (^)(void))success
                                    failure:(void (^)(NSError *))failure
{
  DDLogInfo(@"%@ asking for contacts permission", self.class);
  CFErrorRef error;
  ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
  
  ABAuthorizationStatus oldStatus = [self contactsPermissionStatus];
  ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
    if (granted) {
      [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionContacts];
      [[self sharedManager] sync];
      success();
    } else {
      [DFDefaultsStore setState:DFPermissionStateDenied forPermission:DFPermissionContacts];
      failure((__bridge NSError *)error);
    }
    
    [DFAnalytics logInviteAskContactsWithParameters:@{
                                                      @"oldValue": @(oldStatus),
                                                      @"newValue": @([self contactsPermissionStatus])
                                                      }];
    
  });
}

+ (void)showContactsDeniedAlert
{
  [UIAlertView showSimpleAlertWithTitle:@"Contacts Denied"
                          formatMessage:@"Please go to Settings > Privacy > Contacts and change Strand to on."];
}




@end
