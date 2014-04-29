//
//  DFLocationPinger.m
//  Duffy
//
//  Created by Henry Bridge on 4/28/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFLocationPinger.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <RestKit/RestKit.h>

@interface DFLocationPinger()

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, retain) NSMutableSet *objectsRequestingKeepAlive;
@property (nonatomic, retain) NSDate *lastStarted;

@end

@implementation DFLocationPinger

@synthesize isKeepingAlive = _isSendingPings;

static DFLocationPinger *defaultPinger;

+ (DFLocationPinger *)sharedInstance {
    if (!defaultPinger) {
        defaultPinger = [[super allocWithZone:nil] init];
    }
    return defaultPinger;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedInstance];
}

- (id)init
{
    self = [super init];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.delegate = self;
        self.locationManager.pausesLocationUpdatesAutomatically = NO;
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
        self.objectsRequestingKeepAlive = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)askForLocationPermission
{
    if  (![self canAskForLocationPermission]){
        DDLogInfo(@"TriggerPermissionRequest bailing: locationServices not enabled or auth status not detemined.  locationServices:%d authStatus:%d", [CLLocationManager locationServicesEnabled], [CLLocationManager authorizationStatus]);
        return;
    }
    
    [self.locationManager startUpdatingLocation];
    [self.locationManager stopUpdatingLocation];
}

- (BOOL)canMonitorLocation
{
    return ([CLLocationManager locationServicesEnabled]
            && [CLLocationManager authorizationStatus] == ALAuthorizationStatusAuthorized);
}

- (BOOL)canAskForLocationPermission
{
    return ([CLLocationManager locationServicesEnabled]
            && [CLLocationManager authorizationStatus] == ALAuthorizationStatusNotDetermined);
}


- (void)addObjectRequestingKeepAlive:(id)object{
    [self.objectsRequestingKeepAlive addObject:object];
}

- (void)removeObjectRequestingKeepAlive:(id)object{
    [self.objectsRequestingKeepAlive removeObject:object];
}

- (void)startPings
{
    if (self.objectsRequestingKeepAlive.count > 0) {
        DDLogInfo(@"DFLocationPinger: starting pings.");
        [self.locationManager startUpdatingLocation];
        _isSendingPings = YES;
        self.lastStarted = [NSDate date];
    } else {
        DDLogInfo(@"DFLocationPinger: no observers, will not start pings.");
    }
}

- (void)stopPings
{
    DDLogInfo(@"DFLocationPinger stopping pings.");
    [self.locationManager stopUpdatingLocation];
    _isSendingPings = NO;
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    DDLogInfo(@"Location keepalive.");
    if (![self isDeviceStateGoodForContinuousLocationUpdate]) {
        DDLogInfo(@"DFLocationPinger: device is not in good state for cont background update.  Stopping updates.");
        [self stopPings];
        return;
    } else if (!self.objectsRequestingKeepAlive.count > 0) {
        DDLogInfo(@"DFLocationPinger: no objects requesting keepalive.  Stopping pings.");
        [self stopPings];
        return;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    DDLogWarn(@"DFLocationPinger failed to get location: %@", error.localizedDescription);
}



- (BOOL)isDeviceStateGoodForContinuousLocationUpdate
{
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    AFNetworkReachabilityStatus reachabilityStatus = [[[RKObjectManager sharedManager] HTTPClient] networkReachabilityStatus];
    UIDeviceBatteryState batteryState = [[UIDevice currentDevice] batteryState];
    float batteryLevel = [[UIDevice currentDevice] batteryLevel];
    
    if (reachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi
        && (batteryState == UIDeviceBatteryStateCharging || batteryState == UIDeviceBatteryStateFull)
        && batteryLevel > 0.10) {
        return YES;
    }
    
    DDLogInfo(@"isDeviceInGoodStateForContLocUpdate NO: device appState %d, reachabilityStatus: %d, batteryState: %d batteryLevel:%.02f",
              (int)appState, reachabilityStatus, (int)batteryState, batteryLevel);
    
    return NO;
}


@end
