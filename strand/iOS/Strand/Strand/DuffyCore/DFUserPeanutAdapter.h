//
//  DFUserIDFetcher.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"

@class DFUser;

@interface DFUserPeanutAdapter : NSObject <DFNetworkAdapter>

typedef void (^DFUserFetchSuccessBlock)(DFUser *user);
typedef void (^DFUserFetchFailureBlock)(NSError *error);

- (void)fetchUserForDeviceID:(NSString *)deviceId
            withSuccessBlock:(DFUserFetchSuccessBlock)successBlock
                failureBlock:(DFUserFetchFailureBlock)failureBlock;

- (void)createUserForDeviceID:(NSString *)deviceId
                   deviceName:(NSString *)deviceName
                  phoneNumber:(NSString *)phoneNumberString
                smsAuthString:(NSString *)smsAuthString
             withSuccessBlock:(DFUserFetchSuccessBlock)successBlock
                 failureBlock:(DFUserFetchFailureBlock)failureBlock;


@end
