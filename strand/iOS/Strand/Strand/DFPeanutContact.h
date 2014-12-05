//
//  DFPeanutContact.h
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"
#import "DFPeanutUserObject.h"

#import "RestKit/RestKit.h"

@interface DFPeanutContact : NSObject <DFPeanutObject>

@property (nonatomic) NSNumber *id;
@property (nonatomic) NSNumber *user;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *phone_number;
@property (nonatomic, retain) NSString *phone_type;

typedef NSString *const DFPeanutContactType;
extern DFPeanutContactType DFPeanutContactAddressBook;
extern DFPeanutContactType DFPeanutContactManual;
extern DFPeanutContactType DFPeanutContactInvited;

@property (nonatomic, retain) NSString *contact_type;

- (instancetype)initWithPeanutUser:(DFPeanutUserObject *)user;
- (NSString *)firstName;

@end
