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
  return @[@"id", @"action_type", @"photo", @"user", @"strand", @"user_display_name", @"user_phone_number", @"text", @"time_stamp"];
}

+ (NSArray *)arrayOfLikerNamesFromActions:(NSArray *)actionArray
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutAction *action in actionArray) {
    if (action.action_type == DFPeanutActionFavorite) {
      [result addObject:[action firstNameOrYou]];
    }
  }
  return result;
}

- (NSString *)description
{
  return [[self dictionaryWithValuesForKeys:[DFPeanutAction simpleAttributeKeys]] description];
}

- (NSString *)firstName
{
  if (self.user == [[DFUser currentUser] userID]) {
    return  [[DFUser currentUser] displayName];
  } else {
    return [self firstNameOrYou];
  }
}

- (NSString *)firstNameOrYou
{
  if (self.user == [[DFUser currentUser] userID]) {
    return @"You";
  }
  
  return [[[self fullName] componentsSeparatedByString:@" "] firstObject];
}

- (NSString *)fullNameOrYou
{
  if (self.user == [[DFUser currentUser] userID]) {
    return @"You";
  }
  
  NSString *localName = [[DFContactDataManager sharedManager] localNameFromPhoneNumber:self.user_phone_number];
  if (localName) {
    return localName;
  } else {
    return self.user_display_name;
  }
}

- (NSString *)fullName
{
  if (self.user == [[DFUser currentUser] userID]) {
    return  [[DFUser currentUser] displayName];
  } else {
    return [self fullNameOrYou];
  }
}
@end
