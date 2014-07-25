//
//  DFUserIDFetcher.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutUserObject.h"
#import <RKHTTPUtilities.h>

@interface DFUserPeanutAdapter : NSObject <DFNetworkAdapter>

typedef void (^DFUserFetchSuccessBlock)(DFPeanutUserObject *user);
typedef void (^DFUserFetchFailureBlock)(NSError *error);

- (void)createUserForDeviceID:(NSString *)deviceId
                   deviceName:(NSString *)deviceName
                  phoneNumber:(NSString *)phoneNumberString
                smsAuthString:(NSString *)smsAuthString
             withSuccessBlock:(DFUserFetchSuccessBlock)successBlock
                 failureBlock:(DFUserFetchFailureBlock)failureBlock;

- (void)performRequest:(RKRequestMethod)requestMethod
        withPeanutUser:(DFPeanutUserObject *)peanutUser
               success:(DFUserFetchSuccessBlock)success
               failure:(DFUserFetchFailureBlock)failure;

@end
