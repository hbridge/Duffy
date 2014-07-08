//
//  DFPeanutError.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutError.h"
#import "RestKit/RestKit.h"


@implementation DFPeanutError

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"name", @"description"];
}

@end
