//
//  DFPeanutInviteMessageAdapter.m
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutInviteMessageAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutInvalidField.h"

NSString *const InviteMessagePath = @"get_invite_message";

@implementation DFPeanutInviteMessageAdapter


+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *successReponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInviteMessageResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:InviteMessagePath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  RKResponseDescriptor *errorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:InviteMessagePath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  return [NSArray arrayWithObjects:successReponse, errorResponse, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}

- (void)fetchInviteMessageResponse:(DFPeanutInviteMessageResponseBlock)completionBlock
{
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutInviteMessageResponse alloc] init]
                              method:RKRequestMethodGET
                              path:InviteMessagePath
                              parameters:nil
                              ];
  DDLogInfo(@"%@ getting endpoint: %@", [[self class] description],
            getRequest.URL.absoluteString);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutInviteMessageResponse class]]) {
       DFPeanutInviteMessageResponse *response = mappingResult.firstObject;
       DDLogInfo(@"%@ got invite text: %@", [self.class description], response.invite_message);
       completionBlock(response, nil);
     } else {
       DDLogError(@"%@ unexpected response: %@", [self.class description], mappingResult.firstObject);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     NSError *betterError = [DFPeanutInvalidField invalidFieldsErrorForError:error];
     DDLogError(@"%@ got an error: %@", [self.class description], betterError);
     completionBlock(nil, betterError);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}

@end
