//
//  DFPeanutAction.m
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutAction.h"
#import "RestKit/RestKit.h"
#import "DFPeanutUserObject.h"

#import "DFContactDataManager.h"

@implementation DFPeanutAction

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"action_type", @"user", @"photo", @"share_instance", @"text", @"time_stamp"];
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
