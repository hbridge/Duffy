//
//  DFBackgroundRefreshController.m
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFBackgroundRefreshController.h"
#import <CoreLocation/CoreLocation.h>
#import "DFStrandConstants.h"
#import "DFPeanutJoinableStrandsAdapter.h"
#import "DFPeanutNewPhotosAdapter.h"
#import "DFPeanutSearchObject.h"
#import "DFStatusBarNotificationManager.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"


@interface DFBackgroundRefreshController()

@property (readonly, nonatomic, retain) CLLocationManager *locationManager;
@property (readonly, nonatomic, retain) DFPeanutJoinableStrandsAdapter *joinableStrandsAdapter;
@property (readonly, nonatomic, retain) DFPeanutNewPhotosAdapter *newPhotosAdapter;

@end

@implementation DFBackgroundRefreshController

@synthesize locationManager = _locationManager;
@synthesize joinableStrandsAdapter = _joinableStrandsAdapter;
@synthesize newPhotosAdapter = _newPhotosAdapter;

// We want the upload controller to be a singleton
static DFBackgroundRefreshController *defaultBackgroundController;
+ (DFBackgroundRefreshController *)sharedBackgroundController {
  if (!defaultBackgroundController) {
    defaultBackgroundController = [[super allocWithZone:nil] init];
  }
  return defaultBackgroundController;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedBackgroundController];
}

- (CLLocationManager *)locationManager
{
  if (!_locationManager) {
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
  }
  
  return _locationManager;
}

- (void)startBackgroundRefresh
{
  if ([CLLocationManager locationServicesEnabled]) {
    DDLogInfo(@"Starting to monitor for significant location change.");
    [self.locationManager startMonitoringSignificantLocationChanges];
    [self recordManagerLocation];
  } else {
    DDLogWarn(@"DFBackgroundRefreshController location services not enabled.");
  }
  
  [[UIApplication sharedApplication]
   setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
}

- (void)recordManagerLocation
{
  CLLocationCoordinate2D coordinate = self.locationManager.location.coordinate;
  [[NSUserDefaults standardUserDefaults] setObject:@(coordinate.latitude)
                                            forKey:DFStrandLastKnownLatitudeDefaultsKey];
  [[NSUserDefaults standardUserDefaults] setObject:@(coordinate.longitude)
                                            forKey:DFStrandLastKnownLongitudeDefaultsKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  DDLogInfo(@"Recorded new location: [%.04f,%.04f]", coordinate.latitude, coordinate.longitude);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  DDLogInfo(@"DFBackgroundRefreshController updated location");
  [self recordManagerLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
  NSLog(@"Location manager failed with error: %@", error);
  if ([error.domain isEqualToString:kCLErrorDomain] && error.code == kCLErrorDenied) {
    //user denied location services so stop updating manager
    [manager stopUpdatingLocation];
    DDLogWarn(@"DFBackgroundRefreshController couldn't start updating location:%@", error.description);
  }
}

- (UIBackgroundFetchResult)performBackgroundFetch
{
  DDLogInfo(@"Performing background fetch.");
  
  [self updateJoinableStrands];
  [self updateNewPhotos];
  
  return UIBackgroundFetchResultNewData;
}

- (void)updateJoinableStrands
{
  DDLogInfo(@"Updating joinable strands.");
  [self.joinableStrandsAdapter fetchJoinableStrandsWithCompletionBlock:^(DFPeanutSearchResponse *response) {
    if (!response || !response.result) {
      DDLogError(@"DFBackgroundRefreshController couldn't get joinable strands");
      return;
    }
    
    if (response.objects.count < 1) return;
    
    unsigned int count = 0;
    
    for (DFPeanutSearchObject *searchObject in response.objects) {
      if ([searchObject.type isEqualToString:DFSearchObjectSection]) {
        for (DFPeanutSearchObject *subSearchObject in searchObject.objects) {
          if ([subSearchObject.type isEqualToString:DFSearchObjectPhoto]) {
            count++;
          }
        }
      }
    }
    
    DDLogInfo(@"Found joinable strands with %d photos nearby.", count);
    if (count < 1) return;
    
    NSString *notificationString = [NSString stringWithFormat:@"Take a picture to join a Strand with %d photos.",
                                    count];
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
      [[DFStatusBarNotificationManager sharedInstance] showNotificationWithString:notificationString timeout:2];
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        NSDate *now = [NSDate date];
        localNotification.fireDate = now;
        localNotification.alertBody = notificationString;
        localNotification.applicationIconBadgeNumber = count;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
      });
    }
  }];
}

- (void)updateNewPhotos
{
  DDLogInfo(@"Updating new photo counts.");
  
  NSString *lastFetchDateString = [[NSUserDefaults standardUserDefaults]
                                   objectForKey:DFStrandLastNewPhotosFetchDateDefaultsKey];
  if (!lastFetchDateString) lastFetchDateString = @"";
  
  [self.newPhotosAdapter fetchNewPhotosAfterDate:lastFetchDateString
                                 completionBlock:^(DFPeanutSearchResponse *response)
  {
    if (!response || response.result == NO) {
      DDLogError(@"DFBackgroundRefreshController: update new photos failed.");
      return;
    }
    
    unsigned int count = 0;
    
    for (DFPeanutSearchObject *searchObject in response.objects) {
      if ([searchObject.type isEqualToString:DFSearchObjectSection]) {
        for (DFPeanutSearchObject *subSearchObject in searchObject.objects) {
          if ([subSearchObject.type isEqualToString:DFSearchObjectPhoto]) {
            count++;
          }
        }
      }
    }
    
    DDLogInfo(@"Found joined strands with %d new photos.", count);
    if (count < 1) return;
    
    NSNumber *totalUnseenCount = [[NSUserDefaults standardUserDefaults]
                                  objectForKey:DFStrandUnseenCountDefaultsKey];
    totalUnseenCount = @(totalUnseenCount.intValue + count);
    [[NSUserDefaults standardUserDefaults] setObject:totalUnseenCount
                                              forKey:DFStrandUnseenCountDefaultsKey];
    
    NSString *notificationString = [NSString stringWithFormat:@"%d new photos in your Strands",
                                    totalUnseenCount.intValue];
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
      [[DFStatusBarNotificationManager sharedInstance] showNotificationWithString:notificationString timeout:2];
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        NSDate *now = [NSDate date];
        localNotification.fireDate = now;
        localNotification.alertBody = notificationString;
        localNotification.applicationIconBadgeNumber = count;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
      });
    }

    
    
    [[NSUserDefaults standardUserDefaults]
     setObject:[[NSDateFormatter DjangoDateFormatter] stringFromDate:[NSDate date]]
     forKey:DFStrandLastNewPhotosFetchDateDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }];
}

#pragma mark Networking

- (DFPeanutJoinableStrandsAdapter *)joinableStrandsAdapter
{
  if (!_joinableStrandsAdapter) {
    _joinableStrandsAdapter = [[DFPeanutJoinableStrandsAdapter alloc] init];
  }
  
  return _joinableStrandsAdapter;
}

- (DFPeanutNewPhotosAdapter *)newPhotosAdapter
{
  if (!_newPhotosAdapter) {
    _newPhotosAdapter = [[DFPeanutNewPhotosAdapter alloc] init];
  }
  
  return _newPhotosAdapter;
}


@end
