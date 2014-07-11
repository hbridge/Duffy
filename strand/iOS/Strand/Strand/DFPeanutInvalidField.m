//
//  DFPeanutErrorResponse.m
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutInvalidField.h"
#import "RestKit/RestKit.h"

@implementation DFPeanutInvalidField

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *mapping = [RKObjectMapping mappingForClass:[self class]];
  mapping.forceCollectionMapping = YES;
  [mapping addAttributeMappingFromKeyOfRepresentationToAttribute:@"field_name"];
  [mapping addAttributeMappingsFromDictionary:@{@"(field_name)": @"field_errors"}];
  return mapping;
}

@end
