//
//  EKMappingBlocks+DFMappingBlocks.m
//  Strand
//
//  Created by Derek Parham on 2/4/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "EKMappingBlocks+DFMappingBlocks.h"

@implementation EKMappingBlocks (DFMappingBlocks)

+(EKMappingValueBlock)dateMappingBlock
{
  return ^id(NSString * key, id value) {
    if ([value isKindOfClass:[NSNumber class]])
    {
      NSTimeInterval interval = [value longLongValue];
      NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
      return date;
    }
    return nil;
  };
}

+(EKMappingReverseBlock)dateReverseMappingBlock
{
  return ^id(id value){
    if ([value isKindOfClass:[NSDate class]])
    {
      return [NSNumber numberWithDouble:[value timeIntervalSince1970]];
    }
    return nil;
  };
}



@end
