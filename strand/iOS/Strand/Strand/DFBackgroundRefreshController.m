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
#import "DFPeanutLocationAdapter.h"


@interface DFBackgroundRefreshController()

@property (readonly, nonatomic, retain) CLLocationManager *locationManager;
@property (readonly, nonatomic, retain) DFPeanutJoinableStrandsAdapter *joinableStrandsAdapter;
@property (readonly, nonatomic, retain) DFPeanutNewPhotosAdapter *newPhotosAdapter;
@property (readonly, nonatomic, retain) DFPeanutLocationAdapter *locationAdapter;

@property (atomic) BOOL isNewPhotoCountFetchInProgress;
@property (atomic) BOOL isJoinableStrandsFetchInProgress;

@end

@implementation DFBackgroundRefreshController

@synthesize locationManager = _locationManager;
@synthesize joinableStrandsAdapter = _joinableStrandsAdapter;
@synthesize newPhotosAdapter = _newPhotosAdapter;
@synthesize locationAdapter = _locationAdapter;

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
  DDLogInfo(@"DFBackgroundRefreshController recorded new location: [%.04f,%.04f]",
            location.coordinate.latitude,
            location.coordinate.longitude);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
  DDLogInfo(@"DFBackgroundRefreshController updated location");
  [self recordManagerLocation];
  [self.locationAdapter updateLocation:manager.location
                         withTimestamp:manager.location.timestamp
                       completionBlock:^(BOOL success) {
                       }];
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
  
  NSString *lastFetchDateString = [[NSDateFormatter DjangoDateFormatter]
                                   stringFromDate:self.lastUnseenPhotosFetchDate];
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
    int totalUnseenCount = [DFStrandStore UnseenPhotosCount] + count;
    [DFStrandStore SaveUnseenPhotosCount:totalUnseenCount];
    
    self.lastUnseenPhotosFetchDate = [NSDate date];
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandUnseenPhotosUpdatedNotificationName
     object:self
     userInfo:@{DFStrandUnseenPhotosUpdatedCountKey: @(totalUnseenCount)}];
  }];
}

#pragma mark - Unseen photos fetch date

- (NSDate *)lastUnseenPhotosFetchDate
{
  NSDate *lastFetchDate = [[NSUserDefaults standardUserDefaults]
                           objectForKey:DFStrandLastNewPhotosFetchDateDefaultsKey];
  if (!lastFetchDate) lastFetchDate = [NSDate dateWithTimeIntervalSinceNow:-60*60*3];
  return lastFetchDate;
}

- (void)setLastUnseenPhotosFetchDate:(NSDate *)lastUnseenPhotosFetchDate
{
  [[NSUserDefaults standardUserDefaults]
   setObject:lastUnseenPhotosFetchDate
   forKey:DFStrandLastNewPhotosFetchDateDefaultsKey];
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

- (DFPeanutLocationAdapter *)locationAdapter
{
  if (!_locationAdapter) {
    _locationAdapter = [[DFPeanutLocationAdapter alloc] init];
  }
  
  return _locationAdapter;
}

- (int)numUnseenPhotos
{
  if ([[NSDate date] timeIntervalSinceDate:self.lastUnseenPhotosFetchDate] > 1.0) {
    [self updateNewPhotos];
  }
  
  return [DFStrandStore UnseenPhotosCount];
}

@end
