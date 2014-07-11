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
#import "DFPeanutError.h"


DFActionType DFActionFavorite = @"favorite";

@implementation DFPeanutAction

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"action_type", @"photo", @"user", @"user_display_name"];
}


@end
