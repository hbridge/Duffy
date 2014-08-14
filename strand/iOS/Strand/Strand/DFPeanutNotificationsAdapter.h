//
//  DFPeanutNotificationsAdapter.h
//  Strand
//
//  Created by Derek Parham on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutNotification.h"

@interface DFPeanutNotificationsAdapter : NSObject <DFNetworkAdapter>

typedef void (^DFPeanutNotificationsFetchSuccess)(NSArray *peanutNotifications);
typedef void (^DFPeanutNotificationsFetchFailure)(NSError *error);

- (void)fetchNotifications:(DFPeanutNotificationsFetchSuccess)success
                   failure:(DFPeanutNotificationsFetchFailure)failure;

@end
