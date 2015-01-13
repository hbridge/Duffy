//
//  DFStrandConstants.m
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandConstants.h"
#import "UIColor+DFHelpers.h"
#import <UIColor+BFPaperColors/UIColor+BFPaperColors.h>

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
NSString *const DFStrandNewSwapsDataNotificationName = @"com.duffyapp.Strand.DFStrandNewSwapsDataNotificationName";
NSString *const DFStrandNewPrivatePhotosDataNotificationName = @"com.duffyapp.Strand.DFStrandNewPrivatePhotosDataNotificationName";
NSString *const DFStrandNewActionsDataNotificationName = @"com.duffyapp.Strand.DFStrandNewActionsDataNotificationName";
NSString *const DFStrandNewFriendsDataNotificationName = @"com.duffyapp.Strand.DFStrandNewFriendsDataNotificationName";


NSString *const DFStrandCameraPhotoSavedNotificationName = @"com.duffyapp.Strand.DFStrandCameraPhotoSavedNotificationName";

NSString *const DFPermissionStateChangedNotificationName = @"com.duffyapp.Strand.PermissionChanged";
NSString *const DFPermissionOldStateKey = @"DFPermissionOldStateKey";
NSString *const DFPermissionNewStateKey = @"DFPermissionNewStateKey";
NSString *const DFPermissionTypeKey = @"DFPermissionNameKey";

NSString *const DFPhotosSaveLocationName = @"Swap";

const CGFloat StrandGalleryItemSpacing = 0.5;
const CGFloat StrandGalleryHeaderHeight = 51;

UIColor *DFStrandMainColor;

+(UIColor *)defaultBackgroundColor
{
  return [self strandLightBlue];
}

+ (UIColor *)defaultBarForegroundColor
{
  return [UIColor whiteColor];
}

+ (UIColor *)strandOrange
{
  return [UIColor colorWithRed:236/255.f green:102/255.f blue:30/255.f alpha:1];
}

+ (UIColor *)strandGray
{
  return [UIColor colorWithRedByte:235 green:235 blue:235 alpha:1.0];
}

+ (UIColor *)strandSalmon
{
  return [UIColor colorWithRed:255/255.f green:127/255.f blue:84/255.f alpha:1];
}

+ (UIColor *)strandGreen
{
  return [UIColor colorWithRed:119/255.f green:235/255.f blue:158/255.f alpha:1];
}

+ (UIColor *)strandYellow {
  return [UIColor colorWithRed:255/255.f green:216/255.f blue:82/255.f alpha:1];
}

+ (UIColor *)strandLightBlue
{
  return [UIColor colorWithRedByte:154 green:178 blue:208 alpha:1.0];
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
}

+ (UIColor *)actionButtonBackgroundColor
{
  return [self strandBlue];
}

+ (UIColor *)actionButtonForegroundColor
{
  return [UIColor whiteColor];
}


+ (UIColor *)photoCellBadgeColor
{
  return [[UIColor darkGrayColor] colorWithAlphaComponent:0.8];
}

+ (UIColor *)teamSwapUserColor
{
  return [self strandBlue];
}

+ (UIColor *)alertBackgroundColor
{
  return [self strandRed];
}

+ (UIColor *)alertForegroundColor
{
  return [UIColor whiteColor];
}

+ (UIColor *)unreadNotificationBackgroundColor
{
  return [UIColor colorWithRed:229/255.0 green:239/255.0 blue:251/255.0 alpha:1.0];
}

+ (UIColor *)cardPagerBackground
{
  return [UIColor colorWithRed:47.0/255.0 green:47.0/255.0 blue:47.0/255.0 alpha:1];
}


+ (UIStatusBarStyle)preferredStatusBarStyle
{
  return UIStatusBarStyleLightContent;
}

static NSArray *colors;

+ (NSArray *)profilePhotoStackColors
{
  if (!colors) {
    colors = @[
               [UIColor paperColorRed],
               [UIColor paperColorPink],
               [UIColor paperColorPurple],
               [UIColor paperColorDeepPurple],
               [UIColor paperColorIndigo],
               [UIColor paperColorBlue],
               [UIColor paperColorLightBlue],
               [UIColor paperColorTeal],
               [UIColor paperColorGreen],
               [UIColor paperColorLightGreen],
               [UIColor paperColorOrange800],
               [UIColor paperColorBlueGray],
               [UIColor paperColorBrown],
               ];
  }
  return colors;
}

+ (NSDictionary *)defaultTextStyle
{
  static NSMutableDictionary *defaultStyle = nil;
  if (!defaultStyle) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      // we do this whole song and dance of checking whether the fonts exist because we hit
      // a crash in iOS 7.0.4 where HelveticaNeue-Italic was missing and the dict crashed
      defaultStyle = [NSMutableDictionary new];
      
      NSMutableParagraphStyle *feedParagraphStyle = [NSMutableParagraphStyle new];
      //feedParagraphStyle.lineSpacing = 5;
      feedParagraphStyle.paragraphSpacing = 0;
      feedParagraphStyle.paragraphSpacingBefore = 0;
      UIFont *helveticaNeue = [UIFont fontWithName:@"HelveticaNeue" size:13];
      UIFont *helveticaNeueBold = [UIFont fontWithName:@"HelveticaNeue-Bold" size:13];
      UIFont *helveticaNeueItalic = [UIFont fontWithName:@"HelveticaNeue-Italic" size:13];
      if (helveticaNeue) {
        defaultStyle[@"$default"] = @{NSFontAttributeName : helveticaNeue};
        defaultStyle[@"subtitle"] = @{NSFontAttributeName : [helveticaNeue fontWithSize:11.0],
                                      NSForegroundColorAttributeName : [UIColor lightGrayColor]};
        NSShadow *badgeShadow = [[NSShadow alloc] init];
        badgeShadow.shadowOffset = CGSizeMake(0, 0);
        badgeShadow.shadowBlurRadius = 4.0;
        
        
        defaultStyle[@"photoBadge"] = @{
                                        NSFontAttributeName : [helveticaNeue fontWithSize:11.0],
                                        NSForegroundColorAttributeName : [UIColor whiteColor],
                                        NSShadowAttributeName : badgeShadow,
                                        };
      }
      if (helveticaNeueBold) {
        defaultStyle[@"strong"] = @{NSFontAttributeName : helveticaNeueBold};
        defaultStyle[@"name"] = @{NSFontAttributeName : helveticaNeueBold};
      }
      if (helveticaNeueItalic) {
        defaultStyle[@"em"] = @{NSFontAttributeName : helveticaNeueItalic};
      }
      defaultStyle[@"gray"] = @{NSForegroundColorAttributeName : [UIColor lightGrayColor]};
      defaultStyle[@"feedText"] = @{NSParagraphStyleAttributeName : feedParagraphStyle};
    });
  }
  
  return defaultStyle;
}


@end
