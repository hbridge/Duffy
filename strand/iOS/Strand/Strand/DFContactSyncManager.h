//
//  DFContactSyncManager.h
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@interface DFContactSyncManager : NSObject

+ (DFContactSyncManager *)sharedManager;
- (void)sync;
- (void)forceSync;

+ (ABAuthorizationStatus)contactsPermissionStatus;
+ (void)askForContactsPermissionWithSuccess:(void (^)(void))success
                                    failure:(void (^)(NSError *error))failure;
+ (void)showContactsDeniedAlert;

@end
