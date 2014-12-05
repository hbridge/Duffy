//
//  DFPeanutContact.m
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutContact.h"
#import "NSDictionary+DFJSON.h"

DFPeanutContactType DFPeanutContactAddressBook = @"ab";
DFPeanutContactType DFPeanutContactManual = @"manual";
DFPeanutContactType DFPeanutContactInvited = @"invited";


@implementation DFPeanutContact

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"user", @"name", @"phone_number", @"contact_type"];
}

- (instancetype)initWithPeanutUser:(DFPeanutUserObject *)user
{
  self = [super init];
  if (self) {
    if (user.id) {
      self.user = @(user.id);
    }
    self.name = [user fullName];
    self.phone_number = user.phone_number;
  }
  return self;
}


- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return [dictRep JSONStringPrettyPrinted:NO];
}

- (BOOL)isEqual:(id)object
{
  if (![[object class] isSubclassOfClass:[self class]]) return NO;
  
  DFPeanutContact *otherContact = (DFPeanutContact *)object;
  NSDictionary *selfDict = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  NSDictionary *otherDict = [otherContact dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return [selfDict isEqualToDictionary:otherDict];
}

- (NSString *)firstName
{
  return [[[self name] componentsSeparatedByString:@" "] firstObject];
}

@end
