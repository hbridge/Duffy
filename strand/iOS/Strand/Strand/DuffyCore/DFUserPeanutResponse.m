//
//  DFUserPeanutResponse.m
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUserPeanutResponse.h"
#import "RestKit/RestKit.h"
#import "DFPeanutUserObject.h"

@implementation DFUserPeanutResponse

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"user"
                                                 mapping:[DFPeanutUserObject objectMapping]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"result"];
}

@end
