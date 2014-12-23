//
//  DFUserInfoManager.h
//  Strand
//
//  Created by Henry Bridge on 8/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUserInfoManager : NSObject

+ (DFUserInfoManager *)sharedManager;
- (void)setFirstTimeSyncCount:(NSNumber *)photoCount;
- (void)setLastPhotoTimestamp:(NSDate *)timestamp;
- (void)setLastCheckinTimestamp:(NSDate *)timestamp;

@end
