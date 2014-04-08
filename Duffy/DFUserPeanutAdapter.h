//
//  DFUserIDFetcher.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DFUser;

@interface DFUserPeanutAdapter : NSObject

typedef void (^DFUserFetchCompletionBlock)(DFUser *user);

- (void)fetchUserForDeviceID:(NSString *)deviceId withCompletionBlock:(DFUserFetchCompletionBlock)completionBlock;

@end
