//
//  DFPeanutPushTokenAdapter.m
//  Strand
//
//  Created by Henry Bridge on 6/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutPushTokenAdapter.h"
#import <Restkit/RestKit.h>
#import "DFObjectManager.h"
#import "DFPeanutTrueFalseResponse.h"

static NSString *const RegisterTokenPath = @"register_apns_token";
static NSString *const DeviceTokenKey = @"device_token";

@implementation DFPeanutPushTokenAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *trueFalseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutTrueFalseResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:RegisterTokenPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:trueFalseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}

- (void)registerAPNSToken:(NSData *)apnsToken
          completionBlock:(DFPushTokenResponseBlock)completionBlock
{
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutTrueFalseResponse alloc] init]
                              method:RKRequestMethodGET
                              path:RegisterTokenPath
                              parameters:@{
                                           DeviceTokenKey : apnsToken 
                                           }];
  DDLogInfo(@"DFPeanutPushTokenAdapter getting endpoint: %@", getRequest.URL.absoluteString);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutTrueFalseResponse class]]){
       DFPeanutTrueFalseResponse *response = mappingResult.firstObject;
       completionBlock(response.result);
     } else {
       DDLogWarn(@"Registering APNS token resulted in a non truefalse response.  Mapping result: %@",
                 mappingResult.description);
       completionBlock(NO);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"Registering APNS token failed.  Error: %@", error.description);
     completionBlock(NO);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}


@end
