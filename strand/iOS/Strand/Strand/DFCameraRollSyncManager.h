//
//  DFCameraRollSyncController.h
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFCameraRollSyncManager : NSObject

+ (DFCameraRollSyncManager *)sharedManager;
- (void)sync;
- (void)syncAroundDate:(NSDate *)date;
- (void)cancelSyncOperations;
- (BOOL)isSyncInProgress;

@end
