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

NSString *const RestUserBasePath = @"users/";
NSString *const AuthPhonePath = @"auth_phone/";
NSString *const CreateUserPath = @"users/";
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
  NSMutableArray *responseDescriptors =
  [[super responseDescriptorsForPeanutObjectClass:[DFPeanutUserObject class]
                                        basePath:RestUserBasePath
                                      bulkKeyPath:@"users"] mutableCopy];
  [responseDescriptors
   addObjectsFromArray:@[
                         [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutUserObject objectMapping]
                                                                      method:RKRequestMethodPOST
                                                                 pathPattern:AuthPhonePath
                                                                     keyPath:@"user"
                                                                 statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)],
                         [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                                                      method:RKRequestMethodAny
                                                                 pathPattern:AuthPhonePath
                                                                     keyPath:nil
                                                                 statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)],
                         ]];

  return responseDescriptors;
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutUserObject class] bulkPostKeyPath:@"users"];
}

- (void)authDeviceID:(NSString *)deviceId
          deviceName:(NSString *)deviceName
         phoneNumber:(NSString *)phoneNumberString
       smsAuthString:(NSString *)smsAuthString
    withSuccessBlock:(void(^)(DFPeanutUserObject *peanutUser))successBlock
        failureBlock:(DFPeanutRestFetchFailure)failureBlock
{
  NSDictionary *parameters = @{
                               DFDeviceIDParameterKey: deviceId,
                               DisplayNameKey: deviceName,
                               DFUserPeanutPhoneNumberKey: phoneNumberString,
                               SMSAccessCodeKey: smsAuthString,
                               };
  NSURLRequest *authRequest = [DFObjectManager
                                 requestWithObject:[[DFPeanutUserObject alloc] init]
                                 method:RKRequestMethodGET
                                 path:AuthPhonePath
                                 parameters:parameters];
  DDLogInfo(@"%@ getting endpoint: %@, body:%@ parameters:%@",
            [[self class] description],
            authRequest.URL.absoluteString,
            [[NSString alloc] initWithData:authRequest.HTTPBody encoding:NSUTF8StringEncoding],
            parameters);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:authRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFPeanutUserObject *user = [mappingResult firstObject];
     DDLogInfo(@"Auth device response received resulting user: %@", user);
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

- (void)getCurrentUserWithSuccess:(DFPeanutRestFetchSuccess)succcess
                          failure:(DFPeanutRestFetchFailure)failure
{
  DFPeanutUserObject *user = [[DFPeanutUserObject alloc] init];
  user.id = [[DFUser currentUser] userID];
  [super performRequest:RKRequestMethodGET
               withPath:RestUserBasePath
                objects:@[user] parameters:nil
        forceCollection:NO
                success:succcess
                failure:failure];
}

- (void)createUsersForPhoneNumbers:(NSArray *)phoneNumbers
                withSuccessBlock:(DFPeanutRestFetchSuccess)successBlock
                    failureBlock:(DFPeanutRestFetchFailure)failureBlock
{
  NSArray *peanutUsers = [phoneNumbers arrayByMappingObjectsWithBlock:^id(NSString *phoneNumber) {
    DFPeanutUserObject *newUser = [[DFPeanutUserObject alloc] init];
    newUser.phone_number = phoneNumber;
    return newUser;
  }];
  [self
   performRequest:RKRequestMethodPOST
   withPath:RestUserBasePath
   objects:peanutUsers
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     DDLogInfo(@"%@ createUser received response: %@", self.class, resultObjects);
     successBlock(resultObjects);
   } failure:^(NSError *error) {
     DDLogError(@"%@ createUser error: %@", self.class, error);
     failureBlock(error);
   }];
}

- (void)performRequest:(RKRequestMethod)requestMethod
        withPeanutUser:(DFPeanutUserObject *)peanutUser
               success:(void(^)(DFPeanutUserObject *peanutUser))success
               failure:(DFPeanutRestFetchFailure)failure
{
  [super performRequest:requestMethod withPath:RestUserBasePath
                objects:@[peanutUser]
             parameters:nil forceCollection:NO success:^(NSArray *resultObjects) {
               success(resultObjects.firstObject);
             } failure:failure];
}


@end
