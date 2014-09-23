//
//  NSArray+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 9/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "NSArray+DFHelpers.h"

@implementation NSArray (DFHelpers)

- (NSArray *)arrayByMappingObjectsWithBlock:(id(^)(id input))mappingBlock
{
  NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:self.count];
  for (id input in self) {
    [newArray addObject:mappingBlock(input)];
  }
  return newArray;
}

@end
