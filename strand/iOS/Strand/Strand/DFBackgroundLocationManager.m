//
//  DFBackgroundLocationManager.m
//  Strand
//
//  Created by Henry Bridge on 7/2/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFBackgroundLocationManager.h"
#import "DFLocationStore.h"
#import "DFPeanutLocationAdapter.h"
#import "DFAnalytics.h"

@interface DFBackgroundLocationManager()

@property (readonly, nonatomic, retain) CLLocationManager *locationManager;
@property (readonly, nonatomic, retain) DFPeanutLocationAdapter *locationAdapter;


@end


@implementation DFBackgroundLocationManager

@synthesize locationManager = _locationManager;
@synthesize locationAdapter = _locationAdapter;



// We want the upload controller to be a singleton
static DFBackgroundLocationManager *defaultManager;
+ (DFBackgroundLocationManager *)sharedBackgroundLocationManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedBackgroundLocationManager];
}


- (instancetype)init
{
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appEnteredForeground)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appEnteredBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
      [self.locationManager startUpdatingLocation];
    }
    [self startUpdatingOnSignificantLocationChange];
  }
  return self;
}

- (CLLocationManager *)locationManager
{
  if (!_locationManager) {
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.distanceFilter = 30;
  }
  
  return _locationManager;
}

- (void)startUpdatingOnSignificantLocationChange
{
  if ([CLLocationManager locationServicesEnabled]) {
    DDLogInfo(@"Starting to monitor for significant location change.");
    [self.locationManager startMonitoringSignificantLocationChanges];
  } else {
    DDLogWarn(@"DFBackgroundLocationManager location services not enabled.");
  }
}

- (CLLocation *)lastLocation
{
  CLLocation *uncachedLoc = self.locationManager.location;
  CLLocation *cachedLoc = [DFLocationStore LoadLastLocation];
  if (uncachedLoc) {
    return uncachedLoc;
  } else if (cachedLoc) {
    return cachedLoc;
  }
  
  return nil;
}

- (void)recordManagerLocation
{
  CLLocation *location = self.locationManager.location;
  [DFLocationStore StoreLastLocation:location];
  DDLogInfo(@"DFBackgroundLocationManager recorded new location: [%f,%f]",
            location.coordinate.latitude,
            location.coordinate.longitude);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  CLLocation *newLocation = manager.location;
  CLLocation *lastLocation = [DFLocationStore LoadLastLocation];
  CLLocationDistance distance = CLLocationDistanceMax;
  NSTimeInterval timeDifference = [NSDate timeIntervalSinceReferenceDate];
  if (lastLocation) {
    distance = [newLocation distanceFromLocation:lastLocation];
    timeDifference = [newLocation.timestamp timeIntervalSinceDate:lastLocation.timestamp];
  }
  
  DDLogInfo(@"DFBackgroundLocationManager updated location: <%f, %f> +/- %.02fm @ %@ distance from last:%.6efkm time from last:%.6efs AppState: %d",
            newLocation.coordinate.latitude,
            newLocation.coordinate.longitude,
            newLocation.horizontalAccuracy,
            newLocation.timestamp,
            distance/1000,
            timeDifference,
            (int)[[UIApplication sharedApplication] applicationState]);
  
  if (timeDifference > 0.0 && distance > 30.0) {
    [self recordManagerLocation];
    [self.locationAdapter updateLocation:newLocation
                           withTimestamp:newLocation.timestamp
                                accuracy:newLocation.horizontalAccuracy
                         completionBlock:^(BOOL success) {
                         }];
    [DFAnalytics logLocationUpdated];
  }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
  NSLog(@"Location manager failed with error: %@", error);
  if ([error.domain isEqualToString:kCLErrorDomain] && error.code == kCLErrorDenied) {
    //user denied location services so stop updating manager
    [manager stopUpdatingLocation];
    DDLogWarn(@"DFBackgroundLocationManager couldn't start updating location:%@", error.description);
  }
}

- (DFPeanutLocationAdapter *)locationAdapter
{
  if (!_locationAdapter) {
    _locationAdapter = [[DFPeanutLocationAdapter alloc] init];
  }
  
  return _locationAdapter;
}

#pragma mark - Foreground/background handlers

- (void)appEnteredForeground
{
  DDLogVerbose(@"DFBackgroundLocationManager starting continuous updates.");
  [self.locationManager startUpdatingLocation];
}

- (void)appEnteredBackground
{
  DDLogVerbose(@"DFBackgroundLocationManager stopping continuous updates.");
  [self.locationManager stopUpdatingLocation];
}

@end
