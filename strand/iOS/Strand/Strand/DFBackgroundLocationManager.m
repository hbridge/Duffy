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
#import "DFDefaultsStore.h"
#import "DFSettings.h"

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
+ (DFBackgroundLocationManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [[super allocWithZone:nil] init];
  }
  return defaultManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedManager];
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
    [self syncLocationPermission];
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
  if ([CLLocationManager locationServicesEnabled]
      && [[DFDefaultsStore stateForPermission:DFPermissionLocation] isEqual:DFPermissionStateGranted]) {
    DDLogInfo(@"%@ starting to monitor for significant location change.", self.class);
    [self.locationManager startMonitoringSignificantLocationChanges];
  } else {
    DDLogWarn(@"%@ location services not enabled or permission not granted.", self.class);
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
  DDLogInfo(@"DFBackgroundLocationManager recorded new location: [%f,%f], appstate:%d",
            location.coordinate.latitude,
            location.coordinate.longitude,
            (int)[[UIApplication sharedApplication] applicationState]);
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
      (timeDifference > 60 * 60 * 3
       || distance > 30.0
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
  
  
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
    [[[UIApplication sharedApplication] delegate] application:[UIApplication sharedApplication]
                                           performFetchWithCompletionHandler:nil];
  }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
  NSLog(@"%@ failed with error: %@", self.class, error);
  if (error.code == kCLErrorDenied) {
    [self locationManager:manager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];
    [manager stopMonitoringSignificantLocationChanges];
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
 
}

- (void)appEnteredBackground
{

}

- (void)appResignedActive
{

}


#pragma mark - Requesting permissions

- (void)syncLocationPermission
{
  CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
  DFPermissionStateType currentState = [self permissionStateForCLAuthStatus:status];
  DFPermissionStateType recordedState = [DFDefaultsStore stateForPermission:DFPermissionLocation];
  DDLogInfo(@"%@ currentPermState:%@ ", self.class, currentState);
  if (![recordedState isEqual:currentState]) {
    DDLogInfo(@"%@ recordedState:%@. Changing to %@", self.class, recordedState, currentState);
    [DFDefaultsStore setState:currentState forPermission:DFPermissionLocation];
  }
}

- (BOOL)canPromptForAuthorization
{
  CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
  return (status == kCLAuthorizationStatusNotDetermined);
}

- (BOOL)isPermssionGranted
{
  CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
  return (status == kCLAuthorizationStatusAuthorizedAlways
          || status == kCLAuthorizationStatusAuthorized);
}

- (void)promptForAuthorization
{
  CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
  if (status != kCLAuthorizationStatusNotDetermined) {
    DDLogInfo(@"%@ promprtForAuth but authStatus = %@", self.class,
              [self permissionStateForCLAuthStatus:status]);
    
    if (status == kCLAuthorizationStatusDenied) [DFSettings showPermissionDeniedAlert];
    return;
  }
  
  [DFDefaultsStore setState:DFPermissionStateRequested forPermission:DFPermissionLocation];
  if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
    // iOS 8 method, the actual text displayed is kept in Info.plist
    [self.locationManager requestAlwaysAuthorization];
  } else {
    // iOS 7 method
    [self.locationManager startMonitoringSignificantLocationChanges];
  }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
  if (status == kCLAuthorizationStatusNotDetermined) {
    // as soon as you request access, iOS 8 calls back with this
    // return immediately since we don't have the results yet
    return;
  }
  
  DFPermissionStateType dfPermissionState = [self permissionStateForCLAuthStatus:status];
  [DFDefaultsStore setState:dfPermissionState forPermission:DFPermissionLocation];
  
  if (status == kCLAuthorizationStatusAuthorizedAlways) {
    [self startUpdatingOnSignificantLocationChange];
  }
}
                                        
- (DFPermissionStateType)permissionStateForCLAuthStatus:(CLAuthorizationStatus)status
{
  DFPermissionStateType dfPermissionState;
  if (status == kCLAuthorizationStatusNotDetermined) {
    return nil;
  } else if (status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusAuthorizedAlways) {
    dfPermissionState = DFPermissionStateGranted;
  } else if (status == kCLAuthorizationStatusDenied) {
    dfPermissionState = DFPermissionStateDenied;
  } else if (status == kCLAuthorizationStatusRestricted) {
    dfPermissionState = DFPermissionStateRestricted;
  }
  return dfPermissionState;
}



@end
