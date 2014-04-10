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


+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params;
+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params;
+ (void)logCameraRollScanAddedAssets:(NSInteger)numAdded;
+ (void)logSwitchBetweenPhotos:(NSString *)actionType;

+ (void)logSearchLoadStartedWithQuery:(NSString *)query
                       suggestions:(NSDictionary *)suggestions;
+ (void)logSearchLoadEndedWithQuery:(NSString *)query;

@end
