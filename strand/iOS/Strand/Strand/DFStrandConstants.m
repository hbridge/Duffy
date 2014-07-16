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

NSString *const DFStrandJoinableStrandsNearbyNotificationName = @"DFStrandJoinableStrandsNearbyNotificationName";
NSString *const DFStrandJoinableStrandsCountKey = @"DFStrandJoinableStrandsCountKey";

UIColor *DFStrandMainColor;

+(UIColor *)mainColor
{
  return [UIColor colorWithRed:236/255.f green:101/255.f blue:31/255.f alpha:1];
}

@end
