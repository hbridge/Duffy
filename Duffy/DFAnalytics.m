//
//  DFAnalytics.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAnalytics.h"
#import "Flurry/Flurry.h"
#import "NSDictionary+DFJSON.h"


@interface DFAnalytics()

@property (atomic, retain) NSString *inProgressQueryString;
@property (atomic, retain) NSString *inProgressQuerySuggestions;
@property (atomic, retain) NSDate *inProgressQueryStart;

@end

@implementation DFAnalytics

//Controller logging
NSString* const ControllerViewedEventSuffix = @"Viewed";
NSString* const ControllerClassKey = @"controllerClass";

//Camera roll scan
NSString* const CameraRollScannedEvent = @"CameraRollScanned";
NSString* const PhotosTotalKey = @"numPhotosTotal";
NSString* const PhotosAddedKey = @"numPhotosAdded";

//Photo viewing
NSString* const SwitchedPhotoToPhotoEvent = @"SwitchedPhotoToPhoto";
NSString* const ActionTypeKey = @"actionType";
NSString* const DFAnalyticsActionTypeSwipe = @"swipe";

//Searches
NSString* const SearchExecutedEvent = @"SearchExecuted";
NSString* const QueryKey = @"query";
NSString* const SuggestionsKey = @"searchSuggestions";
NSString* const SLatencyKey = @"SecondsLatency";
NSString* const SearchAbortedEvent = @"SearchExecuted";

static DFAnalytics *defaultLogger;

+ (DFAnalytics *)sharedLogger {
    if (!defaultLogger) {
        defaultLogger = [[super allocWithZone:nil] init];
    }
    return defaultLogger;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedLogger];
}


+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params
{
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc] initWithDictionary:params];
    
    [Flurry logEvent:[self eventNameForControllerViewed:viewController]
      withParameters:allParams timed:YES];
}

+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params
{
    [Flurry endTimedEvent:[self eventNameForControllerViewed:viewController]
           withParameters:params];
}

+ (NSString *)eventNameForControllerViewed:(UIViewController *)viewController
{
    return [NSString stringWithFormat:@"%@%@", [viewController.class description], ControllerViewedEventSuffix];
}

+ (void)logCameraRollScanTotalAssets:(NSInteger)totalAssets addedAssets:(NSInteger)numAdded
{
    [Flurry logEvent:CameraRollScannedEvent
      withParameters:@{
                       PhotosTotalKey: [NSNumber numberWithInteger:totalAssets],
                       PhotosAddedKey: [NSNumber numberWithInteger:numAdded],
                       }];
}

+ (void)logSwitchBetweenPhotos:(NSString *)actionType
{
    [Flurry logEvent:SwitchedPhotoToPhotoEvent withParameters:@{ActionTypeKey: actionType}];
}


+ (void)logSearchLoadStartedWithQuery:(NSString *)query
           suggestions:(NSDictionary *)suggestions
{
    DFAnalytics *sharedLogger = [DFAnalytics sharedLogger];
    if (sharedLogger.inProgressQueryString) {
        // there was already a search in progress, log it as aborted
        [DFAnalytics logSearchAborted:sharedLogger.inProgressQueryString];
    }
    
    sharedLogger.inProgressQueryString = query;
    sharedLogger.inProgressQuerySuggestions = [suggestions JSONString];
    sharedLogger.inProgressQueryStart = [NSDate date];
}

+ (void)logSearchLoadEndedWithQuery:(NSString *)endQuery
{
    DFAnalytics *sharedLogger = [DFAnalytics sharedLogger];
    if (![endQuery isEqualToString:sharedLogger.inProgressQueryString]) {
        NSLog(@"Analytics error: search load end query is different form start query.  Start query: %@ End Query: %@",
              sharedLogger.inProgressQueryString, endQuery);
    }
    
    
    NSTimeInterval queryDuration = [[NSDate date] timeIntervalSinceDate:sharedLogger.inProgressQueryStart];
    NSDictionary *params = @{
                             QueryKey: sharedLogger.inProgressQueryString,
                             SuggestionsKey: sharedLogger.inProgressQuerySuggestions,
                             SLatencyKey: [NSNumber numberWithDouble:queryDuration],
                             };
    
    [Flurry logEvent:SearchExecutedEvent withParameters:params];
    
    sharedLogger.inProgressQueryString = nil;
    sharedLogger.inProgressQueryStart = nil;
    sharedLogger.inProgressQuerySuggestions = nil;
}


+ (void)logSearchAborted:(NSString *)query
{
    DFAnalytics *sharedLogger = [DFAnalytics sharedLogger];
    if (![query isEqualToString:sharedLogger.inProgressQueryString]) {
        NSLog(@"Analytics error: logging search aported with different query from start query.  Query aborted: %@ End Query: %@",
              query, sharedLogger.inProgressQueryString);
    }
    
    NSTimeInterval queryDuration = [[NSDate date] timeIntervalSinceDate:sharedLogger.inProgressQueryStart];
    NSDictionary *params = @{
                             QueryKey: sharedLogger.inProgressQueryString,
                             SuggestionsKey: sharedLogger.inProgressQuerySuggestions,
                             SLatencyKey: [NSNumber numberWithDouble:queryDuration],
                             };
    [Flurry logEvent:SearchAbortedEvent withParameters:params];
    
    sharedLogger.inProgressQueryString = nil;
    sharedLogger.inProgressQueryStart = nil;
}


@end
