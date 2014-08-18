//
//  DFContactsStore.h
//  Strand
//
//  Created by Henry Bridge on 8/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFContact.h"

@interface DFContactsStore : NSObject

@property (readonly, strong, nonatomic) NSManagedObjectContext *context;
@property (readonly, strong, nonatomic) NSManagedObjectModel *model;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

+ (DFContactsStore *)sharedStore;
- (NSArray *)allContacts;
- (NSArray *)contactsModifiedAfterDate:(NSDate *)date;
- (DFContact *)createContactWithName:(NSString *)name phoneNumberString:(NSString *)phoneNumberString;
- (DFContact *)contactWithPhoneNumberString:(NSString *)phoneNumberString;

- (void)saveContext;

@end
