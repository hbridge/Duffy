//
//  DFPeanutTrueFalseResponse.m
//  Strand
//
//  Created by Henry Bridge on 6/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutTrueFalseResponse.h"
#import <RestKit/RestKit.h>

@implementation DFPeanutTrueFalseResponse

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"result"];
}

@end
