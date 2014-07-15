//
//  DFDefaultsStore.h
//  Strand
//
//  Created by Henry Bridge on 7/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFDefaultsStore : NSObject

typedef NSString *const DFDefaultsNotifsStateType;
extern DFDefaultsNotifsStateType NotifsStateNotRequested;
extern DFDefaultsNotifsStateType NotifsStateGranted;
extern DFDefaultsNotifsStateType NotifsStateDenied;
extern DFDefaultsNotifsStateType NotifsStateUnavailable;

+ (void)setLastRemoteNotificationsState:(DFDefaultsNotifsStateType)state;
+ (DFDefaultsNotifsStateType)lastRemoteNotificationsState;
+ (void)setLastNotificationType:(UIRemoteNotificationType)type;
+ (NSNumber *)lastNotificationType;


@end
