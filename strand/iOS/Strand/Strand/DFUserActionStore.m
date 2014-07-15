//
//  DFUserActionStore.m
//  Strand
//
//  Created by Henry Bridge on 7/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUserActionStore.h"

NSString *const UserActionPrefix = @"DFUserActionCount";
DFUserActionType UserActionTakePhoto = @"TakePhoto";

@implementation DFUserActionStore

+ (void)incrementCountForAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionPrefix, action];
  NSNumber *count = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  unsigned int newCount = [count unsignedIntValue] + 1;
  [[NSUserDefaults standardUserDefaults] setObject:@(newCount) forKey:key];
}


+ (unsigned int)actionCountForAction:(DFUserActionType)action
{
  NSString *key = [NSString stringWithFormat:@"%@%@", UserActionPrefix, action];
  NSNumber *count = [[NSUserDefaults standardUserDefaults] objectForKey:key];
  return [count unsignedIntValue];
}

@end
