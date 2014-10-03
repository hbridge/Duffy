//
//  DFNotificationSharedConstants.m
//  Duffy
//
//  Created by Henry Bridge on 4/1/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFNotificationSharedConstants.h"

@implementation DFNotificationSharedConstants


NSString const *DFPhotoChangedNotificationName = @"DFPhotoChangedNotificationName";
NSString const *DFPhotoChangeTypeKey = @"DFPhotoChangeTypeKey";
NSString const *DFPhotoChangeTypeAdded = @"DFPhotoChangeTypeAdded";
NSString const *DFPhotoChangeTypeRemoved = @"DFPhotoChangeTypeRemoved";
NSString const *DFPhotoChangeTypeMetadata = @"DFPhotoChangeTypeMetadata";

NSString *DFUploadStatusNotificationName = @"DFUploadStatusUpdate";
NSString *DFUploadStatusUpdateSessionUserInfoKey = @"sessionStats";

NSString *const DFPhotoStoreCameraRollUpdatedNotificationName = @"DFPhotoStoreCameraRollUpdatedNotificationName";
NSString *const DFCameraRollSyncCompleteNotificationName = @"DFCameraRollSyncCompleteNotificationName";
NSString *const DFUploaderCompleteNotificationName = @"DFUploaderCompleteNotificationName";



@end
