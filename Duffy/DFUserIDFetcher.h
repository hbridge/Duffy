//
//  DFUserIDFetcher.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DFUser;

@interface DFUserIDFetcher : NSObject

typedef void (^DFUserInfoFetchCompletionBlock)(DFUser *user);

- (void)fetchUserInfoForDeviceID:(NSString *)deviceId withCompletionBlock:(DFUserInfoFetchCompletionBlock)completionBlock;

@end
