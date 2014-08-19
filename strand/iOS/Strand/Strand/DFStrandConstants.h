//
//  DFStrandConstants.h
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFStrandConstants : NSObject

extern NSString *const DFStrandLastKnownLocationDefaultsKey;
extern NSString *const DFStrandLastNewPhotosFetchDateDefaultsKey;
extern NSString *const DFStrandUnseenCountDefaultsKey;
extern NSString *const DFStrandGallerySeenDate;

extern NSString *const DFStrandGalleryAppearedNotificationName;

extern NSString *const DFStrandUnseenPhotosUpdatedNotificationName;
extern NSString *const DFStrandUnseenPhotosUpdatedCountKey;
extern NSString *const DFStrandNotificationsUpdatedNotification;
extern NSString *const DFStrandNotificationsUnseenCountKey;

extern NSString *const DFStrandJoinableStrandsNearbyNotificationName;
extern NSString *const DFStrandJoinableStrandsCountKey;
extern NSString *const DFStrandLastFetchAttemptDateDefaultsKey;

extern NSString *const DFStrandReloadRemoteUIRequestedNotificationName;
extern NSString *const DFStrandCameraPhotoSavedNotificationName;


+ (UIColor *)defaultBackgroundColor;
+ (UIColor *)defaultBarForegroundColor;
+ (UIColor *)strongFeedForegroundTextColor;
+ (UIColor *)weakFeedForegroundTextColor;
+ (UIColor *)strandOrange;
+ (UIColor *)strandSalmon;
+ (UIColor *)strandGreen;
+ (UIColor *)strandYellow;

@end
