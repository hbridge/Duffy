//
//  DFSMSVerificationAdapter.m
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSMSVerificationAdapter.h"
#import "DFObjectManager.h"

NSString *const SendSMSPath = @"send_sms_code";
NSString *const PhoneNumberKey = @"phone_number";

@implementation DFSMSVerificationAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *searchResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutTrueFalseResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:SendSMSPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:searchResponseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}



- (void)requestSMSCodeForPhoneNumber:(NSString *)phoneNumberString
                 withCompletionBlock:(DFPeanutSMSVerificationRequestCompletionBlock)completionBlock
{
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutTrueFalseResponse alloc] init]
                              method:RKRequestMethodGET
                              path:SendSMSPath
                              parameters:@{
                                           PhoneNumberKey : phoneNumberString
                                           }];
  DDLogInfo(@"%@ getting endpoint: %@", [[self class] description], getRequest.URL.absoluteString);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFPeanutTrueFalseResponse *response = mappingResult.firstObject;
     completionBlock(response);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"%@ get failed.  Error: %@", [[self class] description], error.description);
     completionBlock(nil);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}

@end
