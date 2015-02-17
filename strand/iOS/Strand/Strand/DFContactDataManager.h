//
//  DFContactDataManager.h
//  Strand
//
//  Created by Derek Parham on 11/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RHAddressBook/AddressBook.h>

@interface DFContactDataManager : NSObject

+ (DFContactDataManager *)sharedManager;

- (NSString *)localNameFromPhoneNumber:(NSString *)phoneNumber;
- (RHPerson *)personFromPhoneNumber:(NSString *)phoneNumber;
- (void)refreshCacheWithCompletion:(DFVoidBlock)completion;

/* All contacts in the phone book, returned as DFPeanutContacts */
- (NSArray *)allPeanutContacts;
- (NSArray *)peanutContactSearchResultsForString:(NSString *)string;

@end
