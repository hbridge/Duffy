//
//  DFPeanutContactAdapter.m
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutContactAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutInvalidField.h"

NSString *const RestContactPath = @"contacts/:id/";
NSString *const RestPostPath = @"contacts/";


@implementation DFPeanutContactAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}


+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *restSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutContact objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:RestContactPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *restPostSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutContact objectMapping]
                                               method:RKRequestMethodPOST
                                          pathPattern:RestPostPath
                                              keyPath:@"contacts"
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *restErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:RestContactPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  return @[restSuccessResponse, restPostSuccessResponse, restErrorResponse];
}

+ (NSArray *)requestDescriptors
{
  RKObjectMapping *mapping = [[DFPeanutContact objectMapping] inverseMapping];
  mapping.forceCollectionMapping = YES;
  RKRequestDescriptor *restRequestDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:mapping
                                        objectClass:[DFPeanutContact class]
                                        rootKeyPath:@"contacts"
                                             method:RKRequestMethodPOST];
  return @[restRequestDescriptor];
}


- (void)postPeanutContacts:(NSArray *)peanutContacts
               success:(DFPeanutContactFetchSuccess)success
               failure:(DFPeanutContactFetchFailure)failure
{
  NSString *requestPath = RestPostPath;
  NSURLRequest *request = [DFObjectManager
                           requestWithObject:peanutContacts
                           method:RKRequestMethodPOST
                           path:requestPath
                           parameters:nil];
  
  DDLogInfo(@"%@ getting endpoint: %@ \n  bodySize:%lu \n",
            [[self class] description],
            request.URL.absoluteString,
            (unsigned long)request.HTTPBody.length);
  DDLogVerbose(@"%@ request body: %@",
               [self.class description],
               [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:request
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DDLogInfo(@"%@ response received with %d objects.",
               [self.class description],
               (int)mappingResult.count);
     success([mappingResult array]);
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
