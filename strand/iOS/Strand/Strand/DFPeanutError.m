//
//  DFPeanutError.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutError.h"
#import "RestKit/RestKit.h"


@implementation DFPeanutError

+ (RKObjectMapping *)rkObjectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromDictionary:@{
                                                      @"name" : @"name",
                                                      @"description" : @"error_description"
                                                      }];
  return objectMapping;
}


@end
