//
//  DFCameraRollSyncController.h
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^DFCameraRollSyncCompletionBlock)(NSDictionary *);

@interface DFCameraRollSyncManager : NSObject

+ (DFCameraRollSyncManager *)sharedManager;
- (void)sync;
- (void)syncAroundDate:(NSDate *)date withCompletionBlock:(DFCameraRollSyncCompletionBlock)completionBlock;
- (void)cancelSyncOperations;
- (BOOL)isSyncInProgress;

@end
