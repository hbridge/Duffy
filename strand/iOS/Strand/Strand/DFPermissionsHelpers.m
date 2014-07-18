//
//  DFPermissionsHelpers.m
//  Strand
//
//  Created by Henry Bridge on 7/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPermissionsHelpers.h"
#import "DFDefaultsStore.h"
#import "DFAnalytics.h"

@implementation DFPermissionsHelpers

+ (BOOL)recordAndLogPermission:(DFPermissionType)permission changedTo:(DFPermissionStateType)currentState
{
  DFPermissionStateType oldState = [DFDefaultsStore stateForPermission:permission];
  if (![oldState isEqualToString:currentState]) {
    [DFAnalytics logPermission:permission changedWithOldState:oldState
                      newState:currentState];
    [DFDefaultsStore setState:currentState forPermission:permission];
    return YES;
  }
  
  return NO;
}

@end
