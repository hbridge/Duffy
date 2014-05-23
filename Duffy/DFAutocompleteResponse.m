//
//  DFAutocompleteResponse.m
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAutocompleteResponse.h"
//#import "DFPeanutAutocompleteResult.h"
#import <Restkit/RestKit.h>

@implementation DFAutocompleteResponse

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[DFAutocompleteResponse class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addAttributeMappingsFromArray:[self relationshipMappings]];
  
  return objectMapping;
}


+ (NSArray *)simpleAttributeKeys
{
  return @[@"query_time"];
}

+ (NSArray *)relationshipMappings
{
  return @[
//   [RKRelationshipMapping relationshipMappingFromKeyPath:@"results"
//                                               toKeyPath:@"results"
//                                             withMapping:[DFPeanutAutocompleteResult objectMapping]]
  ];
}


@end
