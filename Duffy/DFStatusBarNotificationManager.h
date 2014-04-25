//
//  DFStatusBarNotificationManager.h
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFStatusBarNotificationManager : NSObject

typedef enum {
    DFStatusUpdateProgress,
    DFStatusUpdateComplete,
    DFStatusUpdateError,
    DFStatusUpdateCancelled,
    DFStatusUpdateResumed,
} DFStatusUpdateType;


+ (DFStatusBarNotificationManager *)sharedInstance;

- (void)showUploadStatusBarNotificationWithType:(DFStatusUpdateType)updateType
                                   numRemaining:(unsigned long)numRemaining
                                       progress:(float)progress;

@end
