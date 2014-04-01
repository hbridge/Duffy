//
//  NSNotificationCenter+DFThreadingAddons.m
//  Duffy
//
//  Created by Henry Bridge on 4/1/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "NSNotificationCenter+DFThreadingAddons.h"

@implementation NSNotificationCenter (DFThreadingAddons)

- (void)postMainThreadNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    if (![NSThread isMainThread]) {
        NSNotification *notification = [NSNotification notificationWithName:aName object:anObject userInfo:aUserInfo];
        [self performSelectorOnMainThread:@selector(postNotification:)
                               withObject:notification
                            waitUntilDone:NO];
        return;
    }
    
    [self postNotificationName:aName object:anObject userInfo:aUserInfo];
}


- (void)postMainThreadNotification:(NSNotification *)notification
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(postNotification:)
                               withObject:notification
                            waitUntilDone:NO];
        return;
    }
    
    [self postNotification:notification];
}

@end
