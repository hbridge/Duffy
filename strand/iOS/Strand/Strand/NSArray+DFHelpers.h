//
//  NSArray+DFHelpers.h
//  Strand
//
//  Created by Henry Bridge on 9/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (DFHelpers)

- (NSArray *)arrayByMappingObjectsWithBlock:(id(^)(id input))mappingBlock;
- (NSArray *)arrayByRemovingObject:(id)object;

@end
