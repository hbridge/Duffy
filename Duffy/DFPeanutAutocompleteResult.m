//
//  DFPeanutAutocompleteResult.m
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutAutocompleteResult.h"
#import <Restkit/RestKit.h>

@implementation DFPeanutAutocompleteResult

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self attributes]];
    
  return objectMapping;
}


+ (NSArray *)attributes
{
  return @[@"count", @"phrase", @"order"];
}

@end
