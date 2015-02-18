//
//  DFUserIDFetcher.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutRestEndpointAdapter.h"
#import "DFNetworkAdapter.h"
#import "DFPeanutUserObject.h"
#import <RKHTTPUtilities.h>

@interface DFPeanutUserAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)authDeviceID:(NSString *)deviceId
          deviceName:(NSString *)deviceName
         phoneNumber:(NSString *)phoneNumberString
       smsAuthString:(NSString *)smsAuthString
    withSuccessBlock:(void(^)(DFPeanutUserObject *peanutUser))successBlock
        failureBlock:(DFPeanutRestFetchFailure)failureBlock;

- (void)createUsersForPhoneNumbers:(NSArray *)phoneNumbers
                  withSuccessBlock:(DFPeanutRestFetchSuccess)successBlock
                      failureBlock:(DFPeanutRestFetchFailure)failureBlock;

- (void)getCurrentUserWithSuccess:(DFPeanutRestFetchSuccess)succcess
                          failure:(DFPeanutRestFetchFailure)failure;

- (void)performRequest:(RKRequestMethod)requestMethod
        withPeanutUser:(DFPeanutUserObject *)peanutUser
               success:(void(^)(DFPeanutUserObject *peanutUser))success
               failure:(DFPeanutRestFetchFailure)failure;

@end
