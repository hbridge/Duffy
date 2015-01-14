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

- (NSArray *)arrayByRemovingObject:(id)object
{
  NSMutableArray *result = [self mutableCopy];
  [result removeObject:object];
  return result;
}

- (id)objectAfterObject:(id)object wrap:(BOOL)wrap
{
  return [self objectWithDistance:1 fromObject:object wrap:wrap];
}

- (id)objectBeforeObject:(id)object wrap:(BOOL)wrap
{
  return [self objectWithDistance:-1 fromObject:object wrap:wrap];
}

- (id)objectWithDistance:(NSInteger)distance fromObject:(id)object wrap:(BOOL)wrap
{
  if (self.count == 0) return nil;
  NSUInteger objectIndex = [self indexOfObject:object];
  if (objectIndex == NSNotFound)
    return nil;
  
  NSInteger requestedIndex = objectIndex + distance;
  if (requestedIndex >= self.count) {
    if (wrap) requestedIndex = 0;
    else return nil;
  } else if (requestedIndex < 0) {
    if (wrap) requestedIndex = self.count - 1;
    else return nil;
  }
  
  return self[requestedIndex];
}

- (NSArray *)objectsPassingTestBlock:(BOOL (^)(id input))testBlock
{
  NSMutableArray *result = [NSMutableArray new];
  for (id object in self) {
    if (testBlock(object)) [result addObject:object];
  }
  return [[NSArray alloc] initWithArray:result];
}

@end
