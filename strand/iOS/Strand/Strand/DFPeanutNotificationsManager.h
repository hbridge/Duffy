//
//  DFPeanutNotificationsManager.h
//  Strand
//
//  Created by Derek Parham on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutAction.h"

@interface DFPeanutNotificationsManager : NSObject

+ (DFPeanutNotificationsManager *)sharedManager;
- (NSArray *)notifications;
- (NSArray *)unreadNotifications;
- (NSArray *)readNotifications;
- (void)markAllNotificationsAsRead;
- (void)markActionIDsSeen:(NSArray *)actionIDs;
- (BOOL)isActionIDSeen:(DFActionID)actionID;

@end
