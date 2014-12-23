//
//  DFPeanutShareInstance.m
//  Strand
//
//  Created by Derek Parham on 12/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutShareInstance.h"
#import "RestKit/RestKit.h"

@implementation DFPeanutShareInstance

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"user", @"photo", @"users"];
}

- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return dictRep.description;
}

@end
