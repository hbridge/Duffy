//
//  DFPeanutMessageResponse.m
//  Strand
//
//  Created by Henry Bridge on 7/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutMessageResponse.h"
#import "RestKit/RestKit.h"
#import "DFObjectManager.h"
#import "DFPeanutError.h"

@implementation DFPeanutMessageResponse


+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"invalid_fields"
                                                 mapping:[DFPeanutError objectMapping]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"result", @"message", @"expanded_message"];
}

- (NSString *)firstInvalidFieldDescription
{
  DFPeanutError *firstInvalidField = [self.invalid_fields firstObject];
  return firstInvalidField.description;
}



@end
