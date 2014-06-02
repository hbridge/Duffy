//
//  DFPeanutSearchObject.m
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutSearchObject.h"
#import <Restkit/RestKit.h>

@implementation DFPeanutSearchObject

DFSearchObjectType DFSearchObjectSection = @"section";
DFSearchObjectType DFSearchObjectPhoto = @"photo";
DFSearchObjectType DFSearchObjectCluster = @"cluster";


+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"objects" mapping:objectMapping];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"type", @"title", @"id"];
}

@end
