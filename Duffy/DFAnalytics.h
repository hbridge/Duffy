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


+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params;
+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params;
+ (void)logCameraRollScanTotalAssets:(NSInteger)totalAssets addedAssets:(NSInteger)numAdded;
+ (void)logSwitchBetweenPhotos:(NSString *)actionType;

+ (void)logSearchLoadStartedWithQuery:(NSString *)query
                       suggestions:(NSDictionary *)suggestions;
+ (void)logSearchLoadEndedWithQuery:(NSString *)query;
+ (void)logSearchResultPageLoaded:(NSInteger)searchPage;

+ (void)logUploadBegan;
+ (void)logUploadEndedWithResult:(NSString *)resultValue;
+ (void)logUploadEndedWithResult:(NSString *)resultValue numImageBytes:(NSUInteger)imageDataSizeInBytes;
+ (void)logUploadEndedWithResult:(NSString *)resultValue debug:(NSString *)debug;
+ (void)logUploadCancelledWithIsError:(BOOL)isError;
+ (void)logUploadRetryCountExceededWithCount:(unsigned int)count;

+ (void)logPhotoWebviewLoadBegan;
+ (void)logPhotoWebviewLoadEnded;
+ (void)logPhotoWebviewLoadEndedWithResult:(NSString *)resultString;

+ (void)logAutoUploadSettingChanged:(BOOL)isOn;



@end
