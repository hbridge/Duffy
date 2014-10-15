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

NSString *const DFStrandReloadRemoteUIRequestedNotificationName = @"com.duffyapp.Strand.DFStrandRefreshRemoteUIRequestedNotificationName";
NSString *const DFStrandNewInboxDataNotificationName = @"com.duffyapp.Strand.DFStrandNewInboxDataNotificationName";
NSString *const DFStrandNewPrivatePhotosDataNotificationName = @"com.duffyapp.Strand.DFStrandNewPrivatePhotosDataNotificationName";


NSString *const DFStrandCameraPhotoSavedNotificationName = @"com.duffyapp.Strand.DFStrandCameraPhotoSavedNotificationName";

UIColor *DFStrandMainColor;

+(UIColor *)defaultBackgroundColor
{
#ifdef DEBUG
#ifndef TARGET_IPHONE_SIMULATOR
  return [UIColor darkGrayColor];
#endif
  return [self strandRed];
#else
  return [self strandRed];
#endif
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

+ (UIColor *)strandBlue
{
 return [UIColor colorWithRed:74/255.0 green:144/255.0 blue:226/255.0 alpha:1.0];
}

+ (UIColor *)strandRed
{
  return [UIColor colorWithRed:245/255.0 green:81/255.0 blue:48/255.0 alpha:1.0];
}

+ (UIColor *)inviteCellBackgroundColor
{
  return [UIColor whiteColor];
  //return [UIColor colorWithRed:0.95 green:0.95 blue:1.0 alpha:1.0];
}

+ (UIColor *)photoCellBadgeColor
{
  return [[self defaultBackgroundColor] colorWithAlphaComponent:0.8];
}

static NSArray *colors;

+ (NSArray *)profilePhotoStackColors
{
  if (!colors) {
    colors = @[
               [self strandBlue],
               [self strandGreen],
               [self strandOrange],
               [self strandRed],
               [self strandSalmon],
               [self strandYellow],
               [UIColor purpleColor],
               [UIColor brownColor],
               [UIColor cyanColor],
               [UIColor magentaColor],
               ];
  }
  return colors;
}


@end
