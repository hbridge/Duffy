//
//  DFPeanutFriendConnection.m
//  Strand
//
//  Created by Derek Parham on 1/21/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFPeanutFriendConnection.h"
#import <RestKit/RestKit.h>
#import "NSDictionary+DFJSON.h"

@implementation DFPeanutFriendConnection


+ (RKObjectMapping *)rkObjectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id",
           @"user_1",
           @"user_2"];
}

- (NSString *)description
{
  NSDictionary *dictRep = [self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]];
  return dictRep.description;
}



@end
