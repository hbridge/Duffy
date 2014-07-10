//
//  DFNearbyFriendsManager.h
//  Strand
//
//  Created by Henry Bridge on 7/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFNearbyFriendsManager : NSObject

+ (DFNearbyFriendsManager *)sharedManager;
- (NSString *)nearbyFriendsMessage;

@end
