//
//  DFPeanutTrueFalseResponse.m
//  Strand
//
//  Created by Henry Bridge on 6/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutTrueFalseResponse.h"
#import <RestKit/RestKit.h>
#import "DFPeanutError.h"

@implementation DFPeanutTrueFalseResponse

+ (RKObjectMapping *)rkObjectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"invalid_fields"
                                                 mapping:[DFPeanutError rkObjectMapping]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"result"];
}

- (NSString *)firstInvalidFieldDescription
{
  DFPeanutError *firstInvalidField = [self.invalid_fields firstObject];
  return firstInvalidField.description;
}


@end
