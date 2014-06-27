//
//  DFAnalytics.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAnalytics.h"
#import "NSDictionary+DFJSON.h"
#import "LocalyticsSession.h"


@interface DFAnalytics()

@property (atomic, retain) NSString *inProgressQueryString;
@property (atomic, retain) NSString *inProgressQuerySuggestions;
@property (atomic, retain) NSDate *inProgressQueryStart;

@end

@implementation DFAnalytics

/*** Generic Keys and values ***/

NSString* const ActionTypeKey = @"actionType";
NSString* const DFAnalyticsActionTypeSwipe = @"swipe";
NSString* const NumberKey = @"number";

NSString* const SizeInKBKey = @"sizeInKB";
NSString* const ResultKey = @"result";
NSString* const DFAnalyticsValueResultSuccess = @"success";
NSString* const DFAnalyticsValueResultFailure = @"failure";

NSString* const DFAnalyticsIsErrorKey = @"isError";


//Generic value
NSString* const NewValueKey = @"newValue";

/*** Event specific keys ***/

//Controller logging
NSString* const ControllerViewedEventSuffix = @"Viewed";
NSString* const ControllerClassKey = @"controllerClass";

//Camera roll scan
NSString* const CameraRollScannedEvent = @"CameraRollScanned";
NSString* const PhotosTotalKey = @"numPhotosTotal";
NSString* const PhotosAddedKey = @"numPhotosAdded";

//Photo viewing
NSString* const SwitchedPhotoToPhotoEvent = @"SwitchedPhotoToPhoto";

//Searches
NSString* const SearchExecutedEvent = @"SearchExecuted";
NSString* const QueryKey = @"query";
NSString* const SuggestionsKey = @"searchSuggestions";
NSString* const SLatencyKey = @"SecondsLatency";
NSString* const SearchAbortedEvent = @"SearchExecuted";

NSString* const SearchPageLoaded = @"SearchResultPageLoaded";


// Uploads
NSString* const UploadPhotoEvent = @"UploadPhoto";
NSString* const DebugStringKey = @"debug";

NSString* const UploadPhotoCancelled = @"UploadCancelled";
NSString* const UploadRetriesExceeded = @"UploadRetriesExceeded";
NSString* const SessionAvgKBPSKey = @"sessionAvgKBPS";

// Individual photo loads
NSString* const PhotoLoadEvent = @"PhotoLoad";
NSString* const DFAnalyticsValueResultAborted = @"aborted";

// Take picture
NSString* const PhotoTakenEvent = @"PhotoTaken";
NSString* const FlashModeKey = @"flashMode";
NSString* const CameraDeviceKey = @"cameraDevice";

// Save pictire
NSString* const PhotoSavedEvent = @"PhotoSaved";

// App refresh
NSString* const BackgroundRefreshEvent = @"BackgroundRefresh";
NSString* const LocationUpdateEvent = @"LocationUpdated";
NSString* const AppInBackgroundKey = @"appInBackground";


NSString* const NotificationOpenedEvent = @"NotificationOpened";
NSString* const NotificationTypeKey = @"notificationType";


static DFAnalytics *defaultLogger;

+ (void)StartAnalyticsSession
{
#ifdef DEBUG
  [[LocalyticsSession shared]
   LocalyticsSession:@"7790abca456e78bb24ebdbb-8e7455f6-fe36-11e3-9fb0-009c5fda0a25"];
  //[[LocalyticsSession shared] setLoggingEnabled:YES];
#else
  [[LocalyticsSession shared]
   LocalyticsSession:@"66b1e3dfca983d01af7f08d-e84211ee-fe31-11e3-4759-00a426b17dd8"];
#endif
  [[LocalyticsSession shared] enableHTTPS];
  [DFAnalytics ResumeAnalyticsSession];
}

+ (void)ResumeAnalyticsSession
{
  [[LocalyticsSession shared] resume];
  [[LocalyticsSession shared] upload];
}

+ (void)CloseAnalyticsSession
{
  [[LocalyticsSession shared] close];
  [[LocalyticsSession shared] upload];
}

+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params
{
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc] initWithDictionary:params];
    
//    [Flurry logEvent:[self eventNameForControllerViewed:viewController]
//      withParameters:allParams timed:YES];
}

+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params
{
//    [Flurry endTimedEvent:[self eventNameForControllerViewed:viewController]
//           withParameters:params];
}

+ (NSString *)eventNameForControllerViewed:(UIViewController *)viewController
{
    return [NSString stringWithFormat:@"%@%@", [viewController.class description], ControllerViewedEventSuffix];
}

+ (void)logCameraRollScanTotalAssets:(NSUInteger)totalAssets addedAssets:(NSUInteger)numAdded
{
//    [Flurry logEvent:CameraRollScannedEvent
//      withParameters:@{
//                       PhotosTotalKey: [NSNumber numberWithUnsignedInteger:totalAssets],
//                       PhotosAddedKey: [NSNumber numberWithUnsignedInteger:numAdded],
//                       }];
}

+ (void)logSwitchBetweenPhotos:(NSString *)actionType
{
//    [Flurry logEvent:SwitchedPhotoToPhotoEvent withParameters:@{ActionTypeKey: actionType}];
}

+ (void)logUploadEndedWithResult:(NSString *)resultValue
{
//    [Flurry logEvent:UploadPhotoEvent withParameters:@{
//                                                            ResultKey: resultValue,
//                                                            }];
}


+ (void)logUploadEndedWithResult:(NSString *)resultValue numPhotos:(unsigned long)numPhotos sessionAvgThroughputKBPS:(double)KBPS;
{
//    [Flurry logEvent:UploadPhotoEvent withParameters:@{
//                                                            ResultKey: resultValue,
//                                                            NumberKey: [NSNumber numberWithUnsignedInteger:numPhotos],
//                                                            SessionAvgKBPSKey: [NSNumber numberWithDouble:KBPS]
//                                                            }];
}

+ (void)logUploadEndedWithResult:(NSString *)resultValue debug:(NSString *)debug
{
//    [Flurry logEvent:UploadPhotoEvent withParameters:@{
//                                                            ResultKey: resultValue,
//                                                            DebugStringKey: debug
//                                                            }];
}


+ (void)logUploadCancelledWithIsError:(BOOL)isError
{
//    [Flurry logEvent:UploadPhotoCancelled withParameters:@{DFAnalyticsIsErrorKey: [NSNumber numberWithBool:isError]}];
}



+ (void)logUploadRetryCountExceededWithCount:(unsigned int)count
{
//    [Flurry logEvent:UploadRetriesExceeded withParameters:@{NumberKey: [NSNumber numberWithUnsignedInt:count]}];
}

+ (void)logPhotoLoadBegan
{
//    [Flurry logEvent:PhotoLoadEvent withParameters:nil timed:YES];
}

+ (void)logPhotoLoadEnded
{
//    [Flurry endTimedEvent:PhotoLoadEvent withParameters:nil];
}

+ (void)logPhotoLoadEndedWithResult:(NSString *)resultString
{
//    [Flurry endTimedEvent:PhotoLoadEvent withParameters:@{ResultKey: resultString}];
}

+ (void)logPhotoTakenWithCamera:(UIImagePickerControllerCameraDevice)camera
                      flashMode:(UIImagePickerControllerCameraFlashMode)flashMode;
{
//  [Flurry logEvent:PhotoTakenEvent withParameters:@{
//                                                    CameraDeviceKey: @(camera),
//                                                    FlashModeKey: @(flashMode)
//                                                    }];
}

+ (void)logPhotoSavedWithResult:(NSString *)result
{
//  [Flurry logEvent:PhotoSavedEvent withParameters:@{ResultKey: result}];
}


+ (void)logBackgroundAppRefreshOccurred
{
//  [Flurry logEvent:BackgroundRefreshEvent];
}

+ (void)logLocationUpdated
{
//  NSString *backgroundString = [[UIApplication sharedApplication] applicationState]
//  == UIApplicationStateBackground ? @"true" : @"false";
//  
//  [Flurry logEvent:LocationUpdateEvent withParameters:@{
//                                                        AppInBackgroundKey: backgroundString
//                                                        }];
}

+ (void)logNotificationOpened:(NSString *)notificationType
{
//  [Flurry logEvent:NotificationOpenedEvent withParameters:@{
//                                                            NotificationTypeKey: notificationType
//                                                            }];
}



@end
