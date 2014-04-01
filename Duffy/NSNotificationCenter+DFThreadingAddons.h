//
//  NSNotificationCenter+DFThreadingAddons.h
//  Duffy
//
//  Created by Henry Bridge on 4/1/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNotificationCenter (DFThreadingAddons)

- (void)postMainThreadNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
- (void)postMainThreadNotification:(NSNotification *)notification;


@end
