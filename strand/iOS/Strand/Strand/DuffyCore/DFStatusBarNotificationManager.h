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
  DFStatusUpdateThumbnailProgress,
  DFStatusUpdateFullImageProgress,
  DFStatusUpdateComplete,
  DFStatusUpdateError,
  DFStatusUpdateCancelled,
  DFStatusUpdateResumed,
  DFStatusUpdateFullPhotosStopped,
} DFStatusUpdateType;


+ (DFStatusBarNotificationManager *)sharedInstance;

- (void)showUploadStatusBarNotificationWithType:(DFStatusUpdateType)updateType
                                   numRemaining:(unsigned long)numRemaining
                                       progress:(float)progress;

- (void)showNotificationWithString:(NSString *)string timeout:(NSTimeInterval)timeout;

@end
