//
//  DFPeanutStrandInvite.m
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutStrandInvite.h"
#import "RestKit/RestKit.h"
#import "NSDictionary+DFJSON.h"

@implementation DFPeanutStrandInvite

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"user", @"strand", @"phone_number", @"accepted_user_id"];
}

- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return [dictRep JSONStringPrettyPrinted:NO];
}

@end
