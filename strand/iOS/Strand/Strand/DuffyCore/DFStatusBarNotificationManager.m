//
//  DFStatusBarNotificationManager.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFStatusBarNotificationManager.h"
#import <JDStatusBarNotification/JDStatusBarNotification.h>

@implementation DFStatusBarNotificationManager

static DFStatusBarNotificationManager *defaultManager;

+ (DFStatusBarNotificationManager *)sharedInstance {
    if (!defaultManager) {
        defaultManager = [[super allocWithZone:nil] init];
    }
    return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedInstance];
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setNotificationStyle];
    }
    return self;
}

- (void)setNotificationStyle
{
    [JDStatusBarNotification setDefaultStyle:^JDStatusBarStyle *(JDStatusBarStyle *style) {
        style.barColor = [UIColor colorWithWhite:.9686 alpha:1.0]; //.9686 matches the default nav bar color
        style.textColor = [UIColor darkGrayColor];
        style.progressBarColor = [UIColor blueColor];
        style.animationType = JDStatusBarAnimationTypeFade;
        return style;
    }];
}

- (void)showUploadStatusBarNotificationWithType:(DFStatusUpdateType)updateType
                                   numRemaining:(unsigned long)numRemaining
                                       progress:(float)progress
{
        dispatch_async(dispatch_get_main_queue(), ^{
        if (updateType == DFStatusUpdateThumbnailProgress) {
            NSString *statusString = [NSString stringWithFormat:@"Uploading thumbnails. %lu left.", numRemaining];
            
            [JDStatusBarNotification showWithStatus:statusString];
            [JDStatusBarNotification showProgress:progress];
        } else if (updateType == DFStatusUpdateFullImageProgress) {
            NSString *statusString = [NSString stringWithFormat:@"Uploading full images. %lu left.", numRemaining];
            
            [JDStatusBarNotification showWithStatus:statusString];
            [JDStatusBarNotification showProgress:progress];
        } else if (updateType == DFStatusUpdateComplete) {
            [JDStatusBarNotification showWithStatus:@"Upload complete." dismissAfter:2];
        } else if (updateType == DFStatusUpdateError) {
            [JDStatusBarNotification showWithStatus:@"Upload error.  Try again later." dismissAfter:5];
        } else if (updateType == DFStatusUpdateCancelled) {
            [JDStatusBarNotification showWithStatus:@"Upload cancelled." dismissAfter:2];
        } else if (updateType == DFStatusUpdateResumed) {
            [JDStatusBarNotification showWithStatus:@"Upload resuming..." dismissAfter:2];
        } else if (updateType == DFStatusUpdateFullPhotosStopped) {
          NSString *statusString = [NSString stringWithFormat:
                                    @"Connect to Wifi to finish. %lu left.", numRemaining];
          [JDStatusBarNotification showWithStatus:statusString dismissAfter:7];
          [JDStatusBarNotification showProgress:progress];
        }
    });
}

- (void)showNotificationWithString:(NSString *)string timeout:(NSTimeInterval)timeout
{
  [JDStatusBarNotification showWithStatus:string dismissAfter:timeout];
}


@end
