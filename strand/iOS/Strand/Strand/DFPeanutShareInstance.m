//
//  DFPeanutShareInstance.m
//  Strand
//
//  Created by Henry Bridge on 12/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutShareInstance.h"
#import <RestKit/RestKit.h>
#import "NSDictionary+DFJSON.h"

@implementation DFPeanutShareInstance


+ (RKObjectMapping *)rkObjectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id",
           @"user",
           @"photo",
           @"users",
           @"shared_at_timestamp",
           @"last_action_timestamp",
           @"added",
           @"updated"];
}

- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return dictRep.description;
}


@end
