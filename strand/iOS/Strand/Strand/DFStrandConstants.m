//
//  DFStrandConstants.m
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandConstants.h"

@implementation DFStrandConstants

NSString *const DFStrandLastKnownLatitudeDefaultsKey = @"com.duffapp.Strand.lastKnownLatitude";
NSString *const DFStrandLastKnownLongitudeDefaultsKey = @"com.duffapp.Strand.lastKnownLongitude";
NSString *const DFStrandLastKnownLocationRecordedDefaultsKey = @"com.duffapp.Strand.lastKnownLocationRecordedDate";
NSString *const DFStrandLastKnownLocationDefaultsKey = @"com.duffyapp.Strand.DFStrandLastKnownLocationDefaultsKey";
NSString *const DFStrandLastNewPhotosFetchDateDefaultsKey = @"com.duffapp.Strand.lastNewPhotosFetchDate";
NSString *const DFStrandLastFetchAttemptDateDefaultsKey = @"com.duffapp.Strand.lastFetchAttemptDate";
NSString *const DFStrandUnseenCountDefaultsKey = @"com.duffyapp.Strand.unseenCount";
NSString *const DFStrandGallerySeenDate = @"com.duffyapp.Strand.gallerySeen";
NSString *const DFStrandGalleryAppearedNotificationName = @"DFStrandGalleryAppearedNotification";

NSString *const DFStrandUnseenPhotosUpdatedNotificationName = @"DFStrandUnseenPhotosUpdatedNotification";
NSString *const DFStrandUnseenPhotosUpdatedCountKey = @"DFStrandUnseenPhotosUpdatedCountKey";
NSString *const DFStrandNotificationsUpdatedNotification = @"DFStrandNotificationsUpdatedNotification";
NSString *const DFStrandNotificationsUnseenCountKey = @"DFStrandNotificationsUnseenCount";

NSString *const DFStrandJoinableStrandsNearbyNotificationName = @"DFStrandJoinableStrandsNearbyNotificationName";
NSString *const DFStrandJoinableStrandsCountKey = @"DFStrandJoinableStrandsCountKey";

NSString *const DFStrandRefreshRemoteUIRequestedNotificationName = @"com.duffyapp.Strand.DFStrandRefreshRemoteUIRequestedNotificationName";

NSString *const DFStrandPhotoSavedNotificationName = @"com.duffyapp.Strand.DFStrandPhotoSavedNotificationName";

UIColor *DFStrandMainColor;

+(UIColor *)defaultBackgroundColor
{
//#ifdef DEBUG
//  return [UIColor darkGrayColor];
//#else
  return [self strandSalmon];
  //#endif
}

+ (UIColor *)defaultBarForegroundColor
{
  return [UIColor whiteColor];
}

+ (UIColor *)strongFeedForegroundTextColor
{
  return [UIColor blackColor];
}

+ (UIColor *)weakFeedForegroundTextColor
{
  return [UIColor colorWithRed:153/255.f green:153/255.f blue:153/255.f alpha:1];
}

+ (UIColor *)strandOrange
{
  return [UIColor colorWithRed:236/255.f green:102/255.f blue:30/255.f alpha:1];
}

+ (UIColor *)strandSalmon
{
  return [UIColor colorWithRed:255/255.f green:127/255.f blue:84/255.f alpha:1];
}

+ (UIColor *)strandGreen
{
  return [UIColor colorWithRed:159/255.f green:255/255.f blue:198/255.f alpha:1];
}

+ (UIColor *)strandYellow {
  return [UIColor colorWithRed:255/255.f green:216/255.f blue:82/255.f alpha:1];
}

@end
