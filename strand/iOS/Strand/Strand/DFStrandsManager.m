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
#import "DFPeanutFeedObject.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFLocationStore.h"
#import "DFStrandStore.h"
#import "DFPeanutLocationAdapter.h"
#import "DFAnalytics.h"

const NSTimeInterval MinSecondsBetweenFetch = 1.0;

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(galleryAppeared:)
                                                 name:DFStrandGalleryAppearedNotificationName
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(performFetch:)
                                                 name:DFStrandReloadRemoteUIRequestedNotificationName
                                               object:nil];
  }
  return self;
}

- (UIBackgroundFetchResult)performFetch:(NSNotification *)note
{
  if ([[NSDate date] timeIntervalSinceDate:self.lastFetchAttemptDate] < MinSecondsBetweenFetch)
    return UIBackgroundFetchResultNoData;
  
  return UIBackgroundFetchResultNewData;
}

- (void)updateJoinableStrands
{
  if (self.isJoinableStrandsFetchInProgress) return;
  
  self.isJoinableStrandsFetchInProgress = YES;
  CLLocation *lastLocation = [DFLocationStore LoadLastLocation];

  if (!lastLocation) {
    DDLogWarn(@"DFStrandsManager: last location nil, not updating joinable strands");
    self.isJoinableStrandsFetchInProgress = NO;
    return;
  }
  
  [self.joinableStrandsAdapter fetchJoinableStrandsNearLatitude:lastLocation.coordinate.latitude
                                                      longitude:lastLocation.coordinate.longitude
                                                completionBlock:^(DFPeanutObjectsResponse *response)
  {
    self.isJoinableStrandsFetchInProgress = NO;
    if (!response || !response.result) {
      DDLogError(@"DFStrandsManager couldn't get joinable strands");
      return;
    }
    
    unsigned int joinableStrandsCount = (unsigned int)response.objects.count;
    DDLogVerbose(@"%d joinable strands nearby.", joinableStrandsCount);
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandJoinableStrandsNearbyNotificationName
     object:self
     userInfo:@{DFStrandJoinableStrandsCountKey: @(joinableStrandsCount)}];
  }];
}

- (void)updateNewPhotos
{
  if (self.isNewPhotoCountFetchInProgress) return;
  self.isNewPhotoCountFetchInProgress = YES;
  
  NSDate *galleryLastSeenDate = [DFStrandStore galleryLastSeenDate];
  if (!galleryLastSeenDate) galleryLastSeenDate = [NSDate dateWithTimeIntervalSince1970:0];

  [self.newPhotosAdapter fetchNewPhotosAfterDate:galleryLastSeenDate
                                 completionBlock:^(DFPeanutObjectsResponse *response)
  {
    self.isNewPhotoCountFetchInProgress = NO;
    if (!response || response.result == NO) {
      DDLogError(@"DFStrandsManager: update new photos failed.");
      return;
    }
    
    unsigned int oldCount = [DFStrandStore UnseenPhotosCount];
    unsigned int newCount = 0;
    for (DFPeanutFeedObject *searchObject in response.objects) {
      if ([searchObject.type isEqualToString:DFFeedObjectSection]) {
        for (DFPeanutFeedObject *subSearchObject in searchObject.objects) {
          if ([subSearchObject.type isEqualToString:DFFeedObjectPhoto]) {
            newCount++;
          }
        }
      }
    }

    [DFStrandStore SaveUnseenPhotosCount:newCount];
    if (newCount != oldCount) {
      DDLogVerbose(@"%d unseen photos in joined strands since %@", newCount, galleryLastSeenDate);
      [[NSNotificationCenter defaultCenter]
       postNotificationName:DFStrandUnseenPhotosUpdatedNotificationName
       object:self
       userInfo:@{DFStrandUnseenPhotosUpdatedCountKey: @(newCount)}];
    }
  }];
}

#pragma mark - Unseen photos fetch date

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
  if ([[NSDate date] timeIntervalSinceDate:self.lastFetchAttemptDate] > MinSecondsBetweenFetch) {
    [self performFetch:nil];
  }
  
  return [DFStrandStore UnseenPhotosCount];
}

- (void)clearUnseenPhotos
{
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
  [DFStrandStore SaveUnseenPhotosCount:0];
  [[NSNotificationCenter defaultCenter]
   postNotificationName:DFStrandUnseenPhotosUpdatedNotificationName
   object:nil
   userInfo:@{DFStrandUnseenPhotosUpdatedCountKey: @(0)}];
}


- (void)galleryAppeared:(NSNotification *)note
{
  [DFStrandStore setGalleryLastSeenDate:[NSDate date]];
  [self clearUnseenPhotos];
}





@end
