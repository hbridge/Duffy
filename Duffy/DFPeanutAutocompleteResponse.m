//
//  DFPeanutAutocompleteResponse.m
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutAutocompleteResponse.h"
#import <RestKit/RestKit.h>
#import "DFPeanutAutocompleteResult.h"

@implementation DFPeanutAutocompleteResponse

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"results"
                                                 mapping:[DFPeanutAutocompleteResult objectMapping]];
  
  return objectMapping;
}


+ (NSArray *)simpleAttributeKeys
{
  return @[@"query_time"];
}

+ (NSArray *)relationshipMappings
{
  return @[
           [RKRelationshipMapping relationshipMappingFromKeyPath:@"results"
                                                       toKeyPath:@"results"
                                                     withMapping:[DFPeanutAutocompleteResult objectMapping]]
           ];
}


@end
