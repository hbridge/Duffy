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

// Delete
NSString* const PhotoDeletedEvent = @"PhotoDeleted";


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


+ (void)logEvent:(NSString *)eventName withParameters:(NSDictionary *)parameters
{
  [[LocalyticsSession shared] tagEvent:eventName attributes:parameters];
}

+ (void)logEvent:(NSString *)eventName
{
  [[LocalyticsSession shared] tagEvent:eventName];
}


+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params
{
  [[LocalyticsSession shared] tagScreen:[self eventNameForControllerViewed:viewController]];
}

+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params
{
  // Do nothing for now
}

+ (NSString *)eventNameForControllerViewed:(UIViewController *)viewController
{
  NSMutableString *className = [[viewController.class description] mutableCopy];
  //remove DF
  [className replaceOccurrencesOfString:@"DF"
                             withString:@""
                                options:0
                                  range:(NSRange){0,2}];
  //remove ViewController
  [className replaceOccurrencesOfString:@"ViewController"
                             withString:@""
                                options:0
                                  range:(NSRange) {0, className.length}];
  
  
  return className;
}

+ (void)logSwitchBetweenPhotos:(NSString *)actionType
{
    [DFAnalytics logEvent:SwitchedPhotoToPhotoEvent withParameters:@{ActionTypeKey: actionType}];
}

+ (void)logUploadEndedWithResult:(NSString *)resultValue
{
    [DFAnalytics logEvent:UploadPhotoEvent withParameters:@{
                                                            ResultKey: resultValue,
                                                            }];
}


+ (void)logUploadEndedWithResult:(NSString *)resultValue numPhotos:(unsigned long)numPhotos sessionAvgThroughputKBPS:(double)KBPS;
{
    [DFAnalytics logEvent:UploadPhotoEvent withParameters:@{
                                                            ResultKey: resultValue,
                                                            NumberKey: [self bucketStringForNumPhotos:numPhotos],
                                                            SessionAvgKBPSKey: [DFAnalytics bucketStringForKBPS:KBPS]
                                                            }];
}

+ (NSString *)bucketStringForNumPhotos:(NSUInteger)numPhotos
{
  if (numPhotos == 0) return @"0";
  if (numPhotos == 1) return @"1";
  if (numPhotos == 2) return @"2";
  if (numPhotos <= 5) return @"3-5";
  if (numPhotos <= 10) return @"6-10";
  if (numPhotos <= 20) return @"11-20";
  if (numPhotos <= 50) return @"21-50";
  if (numPhotos <= 100) return @"51-100";
  if (numPhotos <= 500) return @"101-500";
  if (numPhotos <= 1000) return @"501-1000";
  if (numPhotos <= 2000) return @"1001-2000";
  if (numPhotos <= 4000) return @"2001-4000";
  if (numPhotos <= 8000) return @"4001-8000";
  return @">8000";
}

+ (NSString *)bucketStringForKBPS:(double)KBPS
{
  if (KBPS < 0.1) return @"<0.1";
  if (KBPS <= 1.0) return @"0.1-1.0";
  if (KBPS <= 10.0) return @"1.01-10";
  if (KBPS <= 50.0) return @"10.1-50.0";
  if (KBPS <= 100.0) return @"50.1-100.0";
  if (KBPS <= 200.0) return @"100.1-200.0";
  if (KBPS <= 500.0) return @"200.1-500.0";
  if (KBPS <= 1000.0) return @"500.1-1000.0";
  return @">1000.0";
}


+ (void)logUploadEndedWithResult:(NSString *)resultValue debug:(NSString *)debug
{
  [DFAnalytics logEvent:UploadPhotoEvent withParameters:@{
                                                          ResultKey: resultValue,
                                                          DebugStringKey: debug
                                                          }];
}


+ (void)logUploadCancelledWithIsError:(BOOL)isError
{
    [DFAnalytics logEvent:UploadPhotoCancelled withParameters:@{DFAnalyticsIsErrorKey: [NSNumber numberWithBool:isError]}];
}



+ (void)logUploadRetryCountExceededWithCount:(unsigned int)count
{
    [DFAnalytics logEvent:UploadRetriesExceeded withParameters:@{NumberKey: [NSNumber numberWithUnsignedInt:count]}];
}


+ (void)logPhotoLoadWithResult:(NSString *)result
{
  [DFAnalytics logEvent:PhotoLoadEvent withParameters:@{ResultKey: result}];
}

+ (void)logPhotoTakenWithCamera:(UIImagePickerControllerCameraDevice)camera
                      flashMode:(UIImagePickerControllerCameraFlashMode)flashMode;
{
  [DFAnalytics logEvent:PhotoTakenEvent withParameters:@{
                                                    CameraDeviceKey: @(camera),
                                                    FlashModeKey: @(flashMode)
                                                    }];
}

+ (void)logPhotoSavedWithResult:(NSString *)result
{
  [DFAnalytics logEvent:PhotoSavedEvent withParameters:@{ResultKey: result}];
}


+ (void)logBackgroundAppRefreshOccurred
{
  [DFAnalytics logEvent:BackgroundRefreshEvent];
}

+ (void)logLocationUpdated
{
  NSString *backgroundString = [[UIApplication sharedApplication] applicationState]
  == UIApplicationStateBackground ? @"true" : @"false";
  
  [DFAnalytics logEvent:LocationUpdateEvent withParameters:@{
                                                        AppInBackgroundKey: backgroundString
                                                        }];
}

+ (void)logNotificationOpened:(NSString *)notificationType
{
  [DFAnalytics logEvent:NotificationOpenedEvent withParameters:@{
                                                            NotificationTypeKey: notificationType
                                                            }];
}

+ (void)logPhotoDeletedWithResult:(NSString *)result
{
  [DFAnalytics logEvent:PhotoDeletedEvent withParameters:@{ResultKey: result}];
}


@end
