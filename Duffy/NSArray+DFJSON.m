//
//  NSArray+DFJSON.m
//  Duffy
//
//  Created by Henry Bridge on 5/13/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "NSArray+DFJSON.h"
#import "NSDictionary+DFJSON.h"
#import "DFJSONConvertible.h"

@implementation NSArray (DFJSON)

- (NSArray *)JSONSafeArray
{
  NSMutableArray *mutableCopy = [self mutableCopy];
  NSMutableIndexSet *indicesToRemove = [[NSMutableIndexSet alloc] init];
  for (unsigned long i = 0; i < mutableCopy.count; i++) {
    id obj = mutableCopy[i];
    
    if (![NSDictionary isJSONSafeValue:obj]) {
      [indicesToRemove addIndex:i];
    }
    
    if ([[obj class] isSubclassOfClass:[NSArray class]]) {
      mutableCopy[i] = [(NSArray *)obj JSONSafeArray];
    } else if ([[obj class] isSubclassOfClass:[NSDictionary class]]) {
      mutableCopy[i] = [(NSDictionary*)obj dictionaryWithNonJSONRemoved];
    } else if ([[obj class] conformsToProtocol:@protocol(DFJSONConvertible)]) {
      NSDictionary *JSONDict = [obj JSONDictionary];
      mutableCopy[i] = JSONDict;
    }
  }
  
  [mutableCopy removeObjectsAtIndexes:indicesToRemove];
  
  return mutableCopy;
}

@end
