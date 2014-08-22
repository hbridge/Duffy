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

- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return [dictRep JSONStringPrettyPrinted:NO];
}

@end
