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
#import "DFLocationStore.h"
#import "DFStrandStore.h"


@interface DFBackgroundRefreshController()

@property (readonly, nonatomic, retain) CLLocationManager *locationManager;
@property (readonly, nonatomic, retain) DFPeanutJoinableStrandsAdapter *joinableStrandsAdapter;
@property (readonly, nonatomic, retain) DFPeanutNewPhotosAdapter *newPhotosAdapter;

@property (atomic) BOOL isNewPhotoCountFetchInProgress;
@property (atomic) BOOL isJoinableStrandsFetchInProgress;

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
  CLLocation *location = self.locationManager.location;
  [DFLocationStore StoreLastLocation:location];
  DDLogInfo(@"DFBAckgroundRefreshController recorded new location: [%.04f,%.04f]",
            location.coordinate.latitude,
            location.coordinate.longitude);
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
  if (self.isJoinableStrandsFetchInProgress) {
    DDLogInfo(@"DFBackgroundRefreshController: joinable strands update already in progress.");
    return;
  } else {
    self.isJoinableStrandsFetchInProgress = YES;
  }
  
  CLLocation *lastLocation = [DFLocationStore LoadLastLocation];

  if (!lastLocation) {
    DDLogWarn(@"DFBackgroundRefreshController: last location nil, not updating joinable strands");
    self.isJoinableStrandsFetchInProgress = NO;
    return;
  }
  
  DDLogInfo(@"Updating joinable strands.");
  [self.joinableStrandsAdapter fetchJoinableStrandsNearLatitude:lastLocation.coordinate.latitude
                                                      longitude:lastLocation.coordinate.longitude
                                                completionBlock:^(DFPeanutSearchResponse *response)
  {
    self.isJoinableStrandsFetchInProgress = NO;
    if (!response || !response.result) {
      DDLogError(@"DFBackgroundRefreshController couldn't get joinable strands");
      return;
    }
    
    unsigned int joinableStrandsCount = (unsigned int)response.objects.count;
    DDLogInfo(@"%d joinable strands nearby.", joinableStrandsCount);
    
    if (response.objects.count < 1) return;
    
    NSString *notificationString = [NSString stringWithFormat:@"Take a picture to join %d Strands nearby.", (int)
                                    joinableStrandsCount];
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
      [[DFStatusBarNotificationManager sharedInstance] showNotificationWithString:notificationString timeout:2];
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        NSDate *now = [NSDate date];
        localNotification.fireDate = now;
        localNotification.alertBody = notificationString;
        localNotification.applicationIconBadgeNumber = 0;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
      });
    }
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandJoinableStrandsNearbyNotificationName
     object:self
     userInfo:@{DFStrandJoinableStrandsCountKey: @(joinableStrandsCount)}];
  }];
}

- (void)updateNewPhotos
{
  if (self.isNewPhotoCountFetchInProgress) {
    DDLogInfo(@"DFBackgroundRefreshController: newPhotoCount update already in progress.");
    return;
  } else {
    self.isNewPhotoCountFetchInProgress = YES;
  }
  DDLogInfo(@"Updating new photo counts.");
  
  NSString *lastFetchDateString = [[NSUserDefaults standardUserDefaults]
                                   objectForKey:DFStrandLastNewPhotosFetchDateDefaultsKey];
  if (!lastFetchDateString) lastFetchDateString = [[NSDateFormatter DjangoDateFormatter]
                                                   stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-60*60*3]];
  
  [self.newPhotosAdapter fetchNewPhotosAfterDate:lastFetchDateString
                                 completionBlock:^(DFPeanutSearchResponse *response)
  {
    self.isNewPhotoCountFetchInProgress = NO;
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
    
    DDLogInfo(@"%d new photos in joined strands.", count);
    if (count < 1) return;
    int totalUnseenCount = [DFStrandStore UnseenPhotosCount] + count;
    [DFStrandStore SaveUnseenPhotosCount:totalUnseenCount];
    
    [[NSUserDefaults standardUserDefaults]
     setObject:[[NSDateFormatter DjangoDateFormatter] stringFromDate:[NSDate date]]
     forKey:DFStrandLastNewPhotosFetchDateDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandUnseenPhotosUpdatedNotificationName
     object:self
     userInfo:@{DFStrandUnseenPhotosUpdatedCountKey: @(count)}];

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

- (int)numUnseenPhotos
{
  return [DFStrandStore UnseenPhotosCount];
}

@end
