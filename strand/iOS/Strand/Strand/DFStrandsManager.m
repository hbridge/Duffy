//
//  DFStrandsManager.m
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandsManager.h"
#import <CoreLocation/CoreLocation.h>
#import "DFStrandConstants.h"
#import "DFPeanutJoinableStrandsAdapter.h"
#import "DFPeanutNewPhotosAdapter.h"
#import "DFPeanutSearchObject.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFLocationStore.h"
#import "DFStrandStore.h"
#import "DFPeanutLocationAdapter.h"
#import "DFAnalytics.h"


@interface DFStrandsManager()

@property (readonly, nonatomic, retain) DFPeanutJoinableStrandsAdapter *joinableStrandsAdapter;
@property (readonly, nonatomic, retain) DFPeanutNewPhotosAdapter *newPhotosAdapter;

@property (atomic) BOOL isNewPhotoCountFetchInProgress;
@property (atomic) BOOL isJoinableStrandsFetchInProgress;

@end

@implementation DFStrandsManager

@synthesize joinableStrandsAdapter = _joinableStrandsAdapter;
@synthesize newPhotosAdapter = _newPhotosAdapter;

// We want the upload controller to be a singleton
static DFStrandsManager *defaultStrandsManager;
+ (DFStrandsManager *)sharedStrandsManager {
  if (!defaultStrandsManager) {
    defaultStrandsManager = [[super allocWithZone:nil] init];
  }
  return defaultStrandsManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
  return [self sharedStrandsManager];
}

- (id)init
{
  self = [super init];
  if (self) {
    
  }
  return self;
}

- (UIBackgroundFetchResult)performFetch
{
  DDLogInfo(@"DFStrandsManager performing fetch.");
  
  if ([[NSDate date] timeIntervalSinceDate:self.lastFetchAttemptDate] < 1.0)
    return UIBackgroundFetchResultNoData;
  
  [self updateJoinableStrands];
  [self updateNewPhotos];
  
  return UIBackgroundFetchResultNewData;
}

- (void)updateJoinableStrands
{
  if (self.isJoinableStrandsFetchInProgress) {
    DDLogInfo(@"DFStrandsManager: joinable strands update already in progress.");
    return;
  } else {
    self.isJoinableStrandsFetchInProgress = YES;
  }
  
  CLLocation *lastLocation = [DFLocationStore LoadLastLocation];

  if (!lastLocation) {
    DDLogWarn(@"DFStrandsManager: last location nil, not updating joinable strands");
    self.isJoinableStrandsFetchInProgress = NO;
    return;
  }
  
  DDLogInfo(@"Updating joinable strands with location: [%f, %f]",
            lastLocation.coordinate.latitude,
            lastLocation.coordinate.longitude);
  [self.joinableStrandsAdapter fetchJoinableStrandsNearLatitude:lastLocation.coordinate.latitude
                                                      longitude:lastLocation.coordinate.longitude
                                                completionBlock:^(DFPeanutSearchResponse *response)
  {
    self.isJoinableStrandsFetchInProgress = NO;
    if (!response || !response.result) {
      DDLogError(@"DFStrandsManager couldn't get joinable strands");
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
    DDLogInfo(@"DFStrandsManager: newPhotoCount update already in progress.");
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
      DDLogError(@"DFStrandsManager: update new photos failed.");
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

- (NSDate *)lastFetchAttemptDate
{
  NSDate *lastFetchDate = [[NSUserDefaults standardUserDefaults]
                           objectForKey:DFStrandLastFetchAttemptDateDefaultsKey];
  if (!lastFetchDate) lastFetchDate = [NSDate dateWithTimeIntervalSince1970:0.0];
  return lastFetchDate;
}

- (void)setLastFetchAttemptDate:(NSDate *)date
{
  [[NSUserDefaults standardUserDefaults] setObject:date
                                            forKey:DFStrandLastFetchAttemptDateDefaultsKey];
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
  if ([[NSDate date] timeIntervalSinceDate:self.lastUnseenPhotosFetchDate] > 1.0) {
    [self updateNewPhotos];
  }
  
  return [DFStrandStore UnseenPhotosCount];
}





@end
