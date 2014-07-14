//
//  DFPeanutInviteMessageResponse.m
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutInviteMessageResponse.h"
#import "RestKit/RestKit.h"

@implementation DFPeanutInviteMessageResponse

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"invite_message", @"invites_remaining"];
}


@end
