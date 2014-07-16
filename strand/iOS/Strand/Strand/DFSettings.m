//
//  DFSettings.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSettings.h"
#import "DFAppInfo.h"
#import "DFUser.h"

@implementation DFSettings

- (void)setDisplayName:(NSString *)displayName
{
  DFUser *currentUser = [DFUser currentUser];
  currentUser.displayName = displayName;
  [DFUser setCurrentUser:currentUser];
}

- (NSString *)displayName
{
  return [[DFUser currentUser] displayName];
}

- (NSString *)version
{
  return [DFAppInfo appInfoString];
}

- (NSString *)phoneNumber
{
  return [[DFUser currentUser] phoneNumberString];
}

@end
