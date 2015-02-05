//
//  DFPeanutSharedStrand.m
//  Strand
//
//  Created by Derek Parham on 12/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutSharedStrand.h"
#import "RestKit/RestKit.h"
#import "NSDictionary+DFJSON.h"

@implementation DFPeanutSharedStrand

+ (RKObjectMapping *)rkObjectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"users", @"strand"];
}

- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return [dictRep JSONStringPrettyPrinted:NO];
}

@end
