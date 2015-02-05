//
//  DFPeanutAction.m
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutAction.h"
#import "DFPeanutUserObject.h"
#import "DFContactDataManager.h"
#import <RestKit/RestKit.h>
#import "EKMappingBlocks+DFMappingBlocks.h"

@implementation DFPeanutAction


+ (RKObjectMapping *)rkObjectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addAttributeMappingsFromArray:[self dateAttributeKeys]];
  return objectMapping;
}


+ (EKObjectMapping *)objectMapping {
  return [EKObjectMapping mappingForClass:self withBlock:^(EKObjectMapping *mapping) {
    [mapping mapPropertiesFromArray:[self simpleAttributeKeys]];
    for (NSString *key in [self dateAttributeKeys]) {
      [mapping mapKeyPath:key toProperty:key
           withValueBlock:[EKMappingBlocks dateMappingBlock]
             reverseBlock:[EKMappingBlocks dateReverseMappingBlock]];
    }
  }];
}

+ (NSArray *)dateAttributeKeys
{
  return @[@"time_stamp"];
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"action_type", @"user", @"photo", @"share_instance", @"text"];
}

- (NSString *)description
{
  return [[self dictionaryWithValuesForKeys:[DFPeanutAction simpleAttributeKeys]] description];
}

- (BOOL)isEqual:(id)object
{
  if (![[object class] isSubclassOfClass:[self class]]) return NO;
  DFPeanutAction *otherAction = (DFPeanutAction *)object;
  
  if ([self.id isEqual:otherAction.id]
      && self.user == otherAction.user
      && (self.text == otherAction.text || [self.text isEqualToString:otherAction.text])) {
    return YES;
  }
  
  return NO;
}

- (NSUInteger)hash
{
  return self.id.integerValue;
}


@end
