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
@property (atomic) BOOL isProcessingServerUpdateLocationRequest;

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appResignedActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
      [self.locationManager startUpdatingLocation];
    }
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
  
  DDLogInfo(@"DFBackgroundLocationManager didUpdateLocation: <%f, %f> +/- %.02fm @ %@ distance from last:%.6efkm time from last:%.6efs AppState: %d",
            newLocation.coordinate.latitude,
            newLocation.coordinate.longitude,
            newLocation.horizontalAccuracy,
            newLocation.timestamp,
            distance/1000,
            timeDifference,
            (int)[[UIApplication sharedApplication] applicationState]);
  
  // If we've moved more than 30 m
  //   or we're processing an explicit request to update our location from the server
  //   or our accuracy is better than what it was before
  // Then update with new location
  if (timeDifference > 0.0 &&
      (distance > 30.0
      || self.isProcessingServerUpdateLocationRequest
      || newLocation.horizontalAccuracy < lastLocation.horizontalAccuracy))
  {
    [self recordManagerLocation];
    [self.locationAdapter updateLocation:newLocation
                           withTimestamp:newLocation.timestamp
                                accuracy:newLocation.horizontalAccuracy
                         completionBlock:^(BOOL success) {
                           DDLogInfo(@"%@ recorded location <%f, %f> and posted to server with success:%@",
                                     self.class,
                                     newLocation.coordinate.latitude,
                                     newLocation.coordinate.longitude,
                                     success ? @"true" : @"false");
                         }];
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

- (void)backgroundUpdateWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  DDLogInfo(@"%@ received background update request.", [self.class description]);
  if (self.isProcessingServerUpdateLocationRequest) {
    DDLogInfo(@"%@ background update request already in progres.  Ignoring.", [self.class description]);
    return;
  }
  self.isProcessingServerUpdateLocationRequest = YES;
  
  [self.locationManager startUpdatingLocation];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    DDLogInfo(@"%@ stopping background location updates and calling completion.", [self.class description]);
    [self.locationManager stopUpdatingLocation];
    self.isProcessingServerUpdateLocationRequest = NO;
    if (completionHandler) {
      completionHandler(UIBackgroundFetchResultNewData);
    } else {
      DDLogWarn(@"%@ backgorundUpdateWithCompletionHandler completion handler nil.",
                [self.class description]);
    }
  });
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

- (void)appResignedActive
{
  DDLogVerbose(@"DFBackgroundLocationManager stopping continuous updates.");
  [self.locationManager stopUpdatingLocation];
}

@end
