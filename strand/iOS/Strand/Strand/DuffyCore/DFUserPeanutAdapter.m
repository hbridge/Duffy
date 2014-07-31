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
#import "DFPeanutUserObject.h"
#import "DFPeanutInvalidField.h"

NSString *const RestUserPath = @"users/:id/";
NSString *const CreateUserPath = @"auth_phone";
NSString *const DisplayNameKey = @"display_name";
NSString *const DFUserPeanutPhoneNumberKey = @"phone_number";
NSString *const SMSAccessCodeKey = @"sms_access_code";

@implementation DFUserPeanutAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}


+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *restSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutUserObject objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:RestUserPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *restErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:RestUserPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  RKResponseDescriptor *createSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutUserObject objectMapping]
                                               method:RKRequestMethodPOST
                                          pathPattern:CreateUserPath
                                              keyPath:@"user"
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *createErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:CreateUserPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  return @[restSuccessResponse, restErrorResponse, createSuccessResponse, createErrorResponse];
}

+ (NSArray *)requestDescriptors
{
  RKObjectMapping *mapping = [[DFPeanutUserObject objectMapping] inverseMapping];
  RKRequestDescriptor *restRequestDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:mapping
                                        objectClass:[DFPeanutUserObject class]
                                        rootKeyPath:nil
                                             method:RKRequestMethodPUT];
  return @[restRequestDescriptor];
}


- (void)performRequest:(RKRequestMethod)requestMethod
              withPeanutUser:(DFPeanutUserObject *)peanutUser
               success:(DFUserFetchSuccessBlock)success
               failure:(DFUserFetchFailureBlock)failure
{
  NSString *requestPath;
  if (requestMethod == RKRequestMethodPOST) {
    requestPath = CreateUserPath;
  } else {
    NSString *idString = [NSString stringWithFormat:@"%llu", peanutUser.id];
    requestPath = [RestUserPath stringByReplacingOccurrencesOfString:@":id" withString:idString];
  }
  //NSDictionary *parameters = [peanutUser requestParameters];

  NSURLRequest *request = [DFObjectManager
                              requestWithObject:peanutUser
                              method:requestMethod
                              path:requestPath
                              parameters:nil];
  
  
  DDLogInfo(@"%@ getting endpoint: %@ \n  body:%@ \n",
            [[self class] description],
            request.URL.absoluteString,
            [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:request
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFPeanutUserObject *user = [mappingResult firstObject];
     DDLogInfo(@"%@ response received: %@", [self.class description], user);
     success(user);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     NSError *betterError = [DFPeanutInvalidField invalidFieldsErrorForError:error];
     DDLogWarn(@"%@ got error: %@", [self.class description], betterError);
     failure(betterError);
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
  NSDictionary *parameters = @{
                               DFDeviceIDParameterKey: deviceId,
                               DisplayNameKey: deviceName,
                               DFUserPeanutPhoneNumberKey: phoneNumberString,
                               SMSAccessCodeKey: smsAuthString,
                               };
  NSURLRequest *createRequest = [DFObjectManager
                                 requestWithObject:[[DFPeanutUserObject alloc] init]
                                 method:RKRequestMethodPOST
                                 path:CreateUserPath
                                 parameters:parameters];
  DDLogInfo(@"%@ getting endpoint: %@, parameters:%@", [[self class] description],
            createRequest.URL.absoluteString,
            parameters);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:createRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFPeanutUserObject *user = [mappingResult firstObject];
     DDLogInfo(@"User create response received resulting user: %@", user);
     successBlock(user);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     NSError *betterError = [DFPeanutInvalidField invalidFieldsErrorForError:error];
     DDLogWarn(@"%@ got error: %@", [self.class description], betterError);
     failureBlock(betterError);
   }];
  
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:operation];
}




@end
