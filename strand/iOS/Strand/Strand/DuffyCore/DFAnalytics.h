//
//  DFAnalytics.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DFAnalytics : NSObject

extern NSString * const DFAnalyticsActionTypeSwipe;
extern NSString* const DFAnalyticsValueResultSuccess;
extern NSString* const DFAnalyticsValueResultFailure;
extern NSString* const DFAnalyticsValueResultAborted;

+ (void)StartAnalyticsSession;
+ (void)ResumeAnalyticsSession;
+ (void)CloseAnalyticsSession;

+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params;
+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params;
+ (void)logSwitchBetweenPhotos:(NSString *)actionType;

+ (void)logUploadEndedWithResult:(NSString *)resultValue;
+ (void)logUploadEndedWithResult:(NSString *)resultValue numPhotos:(unsigned long)numPhotos sessionAvgThroughputKBPS:(double)KBPS;
+ (void)logUploadEndedWithResult:(NSString *)resultValue debug:(NSString *)debug;
+ (void)logUploadCancelledWithIsError:(BOOL)isError;
+ (void)logUploadRetryCountExceededWithCount:(unsigned int)count;

+ (void)logPhotoLoadWithResult:(NSString *)result;

+ (void)logPhotoTakenWithCamera:(UIImagePickerControllerCameraDevice)camera
                      flashMode:(UIImagePickerControllerCameraFlashMode)flashMode;
+ (void)logPhotoSavedWithResult:(NSString *)result;

+ (void)logBackgroundAppRefreshOccurred;
+ (void)logLocationUpdated;
+ (void)logNotificationOpened:(NSString *)notificationType;

@end
