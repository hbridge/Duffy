//
//  DFPeanutSuggestion.m
//  Duffy
//
//  Created by Henry Bridge on 5/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutSuggestion.h"

@implementation DFPeanutSuggestion

@synthesize name;
@synthesize count;
@synthesize order;

+ (NSArray *)attributes
{
  return @[@"name", @"count", @"order"];
}

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[DFPeanutSuggestion class]];
  [objectMapping addAttributeMappingsFromArray:[DFPeanutSuggestion attributes]];
  
  return objectMapping;
}




@end
