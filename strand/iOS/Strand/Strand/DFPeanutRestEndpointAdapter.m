//
//  DFPeanutRestEndpointAdapter.m
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutRestEndpointAdapter.h"
#import "DFPeanutInvalidField.h"
#import "RestKit/RestKit.h"
#import "DFObjectManager.h"

@implementation DFPeanutRestEndpointAdapter

+ (NSArray *)responseDescriptorsForPeanutObjectClass:(Class<DFPeanutObject>)peanutObjectClass
                                                basePath:(NSString *)pathString
{
  NSString *pathWithID = [pathString stringByAppendingPathComponent:@":id/"];
  
  RKResponseDescriptor *restSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[peanutObjectClass objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:pathWithID
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *restErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:pathWithID
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  RKResponseDescriptor *createSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[peanutObjectClass objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:pathString
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *createErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:pathString
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  return @[restSuccessResponse, restErrorResponse, createSuccessResponse, createErrorResponse];
}

+ (NSArray *)requestDescriptorsForPeanutObjectClass:(Class<DFPeanutObject>)peanutObjectClass
                                        rootKeyPath:(NSString *)rootKeyPath
{
  RKObjectMapping *mapping = [[peanutObjectClass objectMapping] inverseMapping];
  RKRequestDescriptor *restRequestDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:mapping
                                        objectClass:peanutObjectClass
                                        rootKeyPath:rootKeyPath
                                             method:RKRequestMethodAny];
  return @[restRequestDescriptor];
}


- (void)performRequest:(RKRequestMethod)requestMethod
              withPath:(NSString *)path
               objects:(NSArray *)objects
       forceCollection:(BOOL)forceCollection
               success:(DFPeanutRestFetchSuccess)success
               failure:(DFPeanutRestFetchFailure)failure
{
  NSURLRequest *request;
  if (objects.count == 1 && !forceCollection) {
    request = [DFObjectManager
               requestWithObject:objects.firstObject
               method:requestMethod
               path:path
               parameters:nil];
  } else {
    request = [DFObjectManager
               requestWithObject:objects
               method:requestMethod
               path:path
               parameters:nil];
  }

  DDLogVerbose(@"%@ getting endpoint: %@ \n  body:%@ \n",
               [[self class] description],
               request.URL.absoluteString,
               [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:request
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DDLogInfo(@"%@ response received: %@", [self.class description], mappingResult);
     success(mappingResult.array);
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
