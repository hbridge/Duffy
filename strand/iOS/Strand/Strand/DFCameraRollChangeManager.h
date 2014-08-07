//
//  DFCameraRollChangeManager.h
//  Strand
//
//  Created by Henry Bridge on 7/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFCameraRollChangeManager : NSObject

+ (DFCameraRollChangeManager *)sharedManager;
- (UIBackgroundFetchResult)backgroundChangeScan;


@end
