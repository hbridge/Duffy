//
//  DFPeanutStrandAdapter.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutStrandAdapter.h"
#import <RestKit/RestKit.h>
#import "DFNetworkingConstants.h"
#import "DFUser.h"
#import "DFObjectManager.h"
#import "DFPeanutInvalidField.h"

NSString *const RestStrandPath = @"strands/:id/";
NSString *const CreateStrandPath = @"strands/";

@implementation DFPeanutStrandAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}


+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *restSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutStrand objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:RestStrandPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *restErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:RestStrandPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  RKResponseDescriptor *createSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutStrand objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:CreateStrandPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *createErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:CreateStrandPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  return @[restSuccessResponse, restErrorResponse, createSuccessResponse, createErrorResponse];
}

+ (NSArray *)requestDescriptors
{
  RKObjectMapping *mapping = [[DFPeanutStrand objectMapping] inverseMapping];
  RKRequestDescriptor *restRequestDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:mapping
                                        objectClass:[DFPeanutStrand class]
                                        rootKeyPath:nil
                                             method:RKRequestMethodAny];
  return @[restRequestDescriptor];
}


- (void)performRequest:(RKRequestMethod)requestMethod
      withPeanutStrand:(DFPeanutStrand *)requestStrand
               success:(DFPeanutStrandFetchSuccess)success
               failure:(DFPeanutStrandFetchFailure)failure
{
  NSString *requestPath;
  if (requestMethod == RKRequestMethodPOST) {
    requestPath = CreateStrandPath;
  } else {
    NSString *idString = [requestStrand.id stringValue];
    requestPath = [RestStrandPath stringByReplacingOccurrencesOfString:@":id" withString:idString];
  }
  //NSDictionary *parameters = [peanutUser requestParameters];
  
  NSURLRequest *request = [DFObjectManager
                           requestWithObject:requestStrand
                           method:requestMethod
                           path:requestPath
                           parameters:nil];
  
  
  DDLogVerbose(@"%@ getting endpoint: %@ \n  body:%@ \n",
               [[self class] description],
               request.URL.absoluteString,
               [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:request
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFPeanutStrand *resultStrand = [mappingResult firstObject];
     DDLogInfo(@"%@ response received: %@", [self.class description], resultStrand);
     success(resultStrand);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     NSError *betterError = [DFPeanutInvalidField invalidFieldsErrorForError:error];
     DDLogWarn(@"%@ got error: %@", [self.class description], betterError);
     failure(betterError);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:operation];
}


@end
