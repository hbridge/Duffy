//
//  DFCameraRollSyncController.h
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFCameraRollSyncController : NSObject

+ (DFCameraRollSyncController *)sharedSyncController;
- (void)asyncSyncToCameraRoll;
- (void)cancelSyncOperations;
- (BOOL)isSyncInProgress;

@end
