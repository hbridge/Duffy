//
//  DFNotificationSharedConstants.h
//  Duffy
//
//  Created by Henry Bridge on 4/1/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFNotificationSharedConstants : NSObject


/*
 DFPhotoChangedNotifications
 Come with user info in format:
 {
    NSManagedObjectID1 : DFPhotoChangeType1,
    NSManagedObjectID2 : DFPhotoChangeType2
    ...
 }
 
 
 */
extern NSString *DFPhotoChangedNotificationName;
extern NSString *DFPhotoChangeTypeKey;
extern NSString *DFPhotoChangeTypeAdded;
extern NSString *DFPhotoChangeTypeRemoved;
extern NSString *DFPhotoChangeTypeMetadata;

extern NSString *DFUploadStatusNotificationName;
extern NSString *DFUploadStatusUpdateSessionUserInfoKey;
extern NSString *const DFPhotoStoreCameraRollUpdatedNotificationName;
extern NSString *const DFCameraRollSyncCompleteNotificationName;



@end
