//
//  DFUserIDFetcher.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUserPeanutAdapter.h"
#import <RestKit/RestKit.h>
#import "DFNetworkingConstants.h"
#import "DFUser.h"
#import "DFObjectManager.h"
#import "DFUserPeanutResponse.h"

NSString *const GetUserPath = @"get_user";
NSString *const CreateUserPath = @"create_user";
NSString *const DeviceNameKey = @"device_name";
NSString *const DFUserPeanutPhoneNumberKey = @"phone_number";
NSString *const SMSAccessCodeKey = @"access_code";

@implementation DFUserPeanutAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}


+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *getUserResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFUserPeanutResponse objectMapping]
                                               method:RKRequestMethodGET
                                          pathPattern:GetUserPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *createUserResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFUserPeanutResponse objectMapping]
                                               method:RKRequestMethodPOST
                                          pathPattern:CreateUserPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  return @[getUserResponseDescriptor, createUserResponseDescriptor];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}


- (void)fetchUserForDeviceID:(NSString *)deviceId
            withSuccessBlock:(DFUserFetchSuccessBlock)successBlock
                failureBlock:(DFUserFetchFailureBlock)failureBlock
{
  NSURLRequest *getRequest = [DFObjectManager requestWithObject:[[DFUserPeanutResponse alloc] init]
                                                         method:RKRequestMethodGET
                                                           path:GetUserPath
                                                     parameters:@{
                                                                  DFDeviceIDParameterKey: deviceId
                                                                  }];
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFUserPeanutResponse *response = [mappingResult firstObject];
     
     DFUser *result = [[DFUser alloc] init];
     if (response.result) {
       result.userID = response.user.id;
       result.deviceID = response.user.phone_id;
       result.firstName = response.user.first_name;
       result.lastName = response.user.last_name;
     }  else {
       result = nil;
     }
     
     DDLogInfo(@"User Info response received.  result:%d, User:%@",
               response.result,
               result.description);
     
     successBlock(result);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogError(@"User Info fetch failed.  Error: %@", error.localizedDescription);
     if (failureBlock) {
       failureBlock(error);
     }
   }];
  
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:operation];
}

- (void)createUserForDeviceID:(NSString *)deviceId
                   deviceName:(NSString *)deviceName
                  phoneNumber:(NSString *)phoneNumberString
                smsAuthString:(NSString *)smsAuthString
             withSuccessBlock:(DFUserFetchSuccessBlock)successBlock
                 failureBlock:(DFUserFetchFailureBlock)failureBlock
{
  NSURLRequest *createRequest = [DFObjectManager
                                 requestWithObject:[[DFUserPeanutResponse alloc] init]
                                 method:RKRequestMethodPOST
                                 path:CreateUserPath
                                 parameters:@{
                                              DFDeviceIDParameterKey: deviceId,
                                              DeviceNameKey: deviceName,
                                              DFUserPeanutPhoneNumberKey: phoneNumberString,
                                              SMSAccessCodeKey: smsAuthString,
                                              }];
  DDLogInfo(@"%@ getting endpoint: %@", [[self class] description], createRequest.URL.absoluteString);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:createRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFUserPeanutResponse *response = [mappingResult firstObject];
     DDLogInfo(@"User create response received.  result:%d", response.result);
     
     
     if (response.result) {
       DFUser *result = [[DFUser alloc] init];
       result.userID = response.user.id;
       result.deviceID = response.user.phone_id;
       result.firstName = response.user.first_name;
       result.lastName = response.user.last_name;
       successBlock(result);
     }  else {
       failureBlock([NSError errorWithDomain:@"com.duffyapp.Strand"
                                        code:-7
                                    userInfo:@{
                                               NSLocalizedDescriptionKey: response.debug ?
                                                 response.debug : @"Could not create account"
                                               }
                     ]);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogError(@"User create failed.  Error: %@", error.localizedDescription);
     failureBlock(error);
   }];
  
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:operation];
}




@end
