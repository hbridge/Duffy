//
//  DFDefaultsStore.m
//  Strand
//
//  Created by Henry Bridge on 7/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDefaultsStore.h"

@implementation DFDefaultsStore

NSString *const DFDefaultsNotifsStateKey = @"DFDefaultsNotifsState";
DFDefaultsNotifsStateType NotifsStateNotRequested = @"NotRequested";
DFDefaultsNotifsStateType NotifsStateGranted = @"Granted";
DFDefaultsNotifsStateType NotifsStateDenied = @"Denied";
DFDefaultsNotifsStateType NotifsStateUnavailable = @"Unavailable";

NSString *const DFDefaultsNotifsTypeKey = @"DFStrandLastNotifTypes";

+ (void)setLastRemoteNotificationsState:(DFDefaultsNotifsStateType)state
{
  [[NSUserDefaults standardUserDefaults] setObject:state forKey:DFDefaultsNotifsStateKey];
}

+ (DFDefaultsNotifsStateType)lastRemoteNotificationsState
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:DFDefaultsNotifsStateKey];
}

+ (void)setLastNotificationType:(UIRemoteNotificationType)type
{
  [[NSUserDefaults standardUserDefaults] setObject:@(type) forKey:DFDefaultsNotifsTypeKey];
}

+ (NSNumber *)lastNotificationType
{
  return [[NSUserDefaults standardUserDefaults] objectForKey:DFDefaultsNotifsTypeKey];
}



@end
