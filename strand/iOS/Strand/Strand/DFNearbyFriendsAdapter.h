//
//  DFNearbyFriendsAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutMessageResponse.h"
#import <CoreLocation/CoreLocation.h>

typedef void (^DFPeanutNearbyFriendsCompletionBlock)(DFPeanutMessageResponse *response, NSError *error);

@interface DFNearbyFriendsAdapter : NSObject <DFNetworkAdapter>

- (void)fetchNearbyFriendsMessageForLocation:(CLLocation *)location
                             completionBlock:(DFPeanutNearbyFriendsCompletionBlock)competionBlock;

@end
