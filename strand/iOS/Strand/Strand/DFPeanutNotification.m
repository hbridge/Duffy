//
//  DFPeanutNotification.m
//  Strand
//
//  Created by Derek Parham on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutNotification.h"
#import "RestKit/RestKit.h"

@implementation DFPeanutNotification

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"photo_id", @"action_text", @"actor_user", @"time"];
}

- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return dictRep.description;
}

@end
