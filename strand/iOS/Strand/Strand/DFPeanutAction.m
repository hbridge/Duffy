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

@implementation DFPeanutAction

+ (RKObjectMapping *)objectMapping {
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id", @"action_type", @"photo", @"user", @"strand", @"user_display_name"];
}

+ (NSArray *)arrayOfLikerNamesFromActions:(NSArray *)actionArray
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutAction *action in actionArray) {
    if (action.action_type == DFPeanutActionFavorite) {
      if (action.user == [[DFUser currentUser] userID]) {
        [result addObject:@"You"];
      } else {
        [result addObject:action.user_display_name];
      }
    }
  }
  return result;
}


@end
