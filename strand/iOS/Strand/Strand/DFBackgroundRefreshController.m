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
#import "DFPeanutSearchObject.h"

@interface DFBackgroundRefreshController()

@property (readonly, nonatomic, retain) CLLocationManager *locationManager;
@property (readonly, nonatomic, retain) DFPeanutJoinableStrandsAdapter *joinableStrandsAdapter;

@end

@implementation DFBackgroundRefreshController

@synthesize locationManager = _locationManager;
@synthesize joinableStrandsAdapter = _joinableStrandsAdapter;

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
  
  [self.joinableStrandsAdapter fetchJoinableStrandsWithCompletionBlock:^(DFPeanutSearchResponse *response) {
    if (!response || !response.result) {
      DDLogError(@"DFBackgroundRefreshController couldn't get joinable strands");
      return;
    }
    
    if (response.objects.count < 1) return;
    
    unsigned int count = 0;
    
    for (DFPeanutSearchObject *searchObject in response.objects) {
      if (searchObject.type == DFSearchObjectSection) {
        for (DFPeanutSearchObject *subSearchObject in searchObject.objects) {
          if (subSearchObject.type == DFSearchObjectPhoto) {
            count++;
          }
        }
      }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [[UIApplication sharedApplication] cancelAllLocalNotifications];
      UILocalNotification *localNotification = [[UILocalNotification alloc] init];
      NSDate *now = [NSDate date];
      localNotification.fireDate = now;
      localNotification.alertBody = [NSString stringWithFormat:@"Take a picture to join a Strand with %du photos.", count];
      localNotification.applicationIconBadgeNumber = count;
      [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    });
  }];
  
  return UIBackgroundFetchResultNewData;
}

#pragma mark Networking

- (DFPeanutJoinableStrandsAdapter *)joinableStrandsAdapter
{
  if (!_joinableStrandsAdapter) {
    _joinableStrandsAdapter = [[DFPeanutJoinableStrandsAdapter alloc] init];
  }
  
  return _joinableStrandsAdapter;
}


@end
