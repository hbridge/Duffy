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
#import "AppDelegate.h"

@implementation DFPeanutRestEndpointAdapter

+ (NSArray *)responseDescriptorsForPeanutObjectClass:(Class<DFPeanutObject>)peanutObjectClass
                                                basePath:(NSString *)pathString
                                         bulkKeyPath:(NSString *)bulkKeyPath
{
  NSString *pathWithID = [pathString stringByAppendingString:@":id/"];
  
  RKResponseDescriptor *restSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[peanutObjectClass rkObjectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:pathWithID
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  RKResponseDescriptor *restErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField rkObjectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:pathWithID
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  RKResponseDescriptor *createSuccessResponse;
  if (bulkKeyPath) {
    createSuccessResponse =
    [RKResponseDescriptor responseDescriptorWithMapping:[peanutObjectClass rkObjectMapping]
                                                 method:RKRequestMethodAny
                                            pathPattern:pathString
                                                keyPath:bulkKeyPath
                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  } else {
    createSuccessResponse =
    [RKResponseDescriptor responseDescriptorWithMapping:[peanutObjectClass rkObjectMapping]
                                                 method:RKRequestMethodAny
                                            pathPattern:pathString
                                                keyPath:nil
                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  }
  
  RKResponseDescriptor *createErrorResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutInvalidField rkObjectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:pathString
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassClientError)];
  
  return @[restSuccessResponse, restErrorResponse, createSuccessResponse, createErrorResponse];
}

+ (NSArray *)requestDescriptorsForPeanutObjectClass:(Class<DFPeanutObject>)peanutObjectClass
                                        bulkPostKeyPath:(NSString *)bulkPostKeyPath
{
  RKObjectMapping *mapping = [[peanutObjectClass rkObjectMapping] inverseMapping];
  RKRequestDescriptor *bulkPostRequestDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:mapping
                                        objectClass:peanutObjectClass
                                        rootKeyPath:bulkPostKeyPath
                                             method:RKRequestMethodPOST];
  RKRequestDescriptor *patchRequestDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:mapping
                                        objectClass:peanutObjectClass
                                        rootKeyPath:nil
                                             method:RKRequestMethodPATCH];
  
  
  return @[bulkPostRequestDescriptor, patchRequestDescriptor];
}


- (void)performRequest:(RKRequestMethod)requestMethod
              withPath:(NSString *)path
               objects:(NSArray *)objects
            parameters:(NSDictionary *)parameters
       forceCollection:(BOOL)forceCollection
               success:(DFPeanutRestFetchSuccess)success
               failure:(DFPeanutRestFetchFailure)failure
{
  NSURLRequest *request;
  if (objects.count == 1 && !forceCollection) {
    NSString *objectPath = path;
    id object = objects.firstObject;
    if ([object respondsToSelector:@selector(id)]) {
      NSNumber *objectID = [object valueForKey:@"id"];
      if (objectID) {
        objectPath = [[path stringByAppendingPathComponent:[objectID stringValue]] stringByAppendingString:@"/"];
      }
    }
    request = [DFObjectManager
               requestWithObject:objects.firstObject
               method:requestMethod
               path:objectPath
               parameters:parameters];
  } else {
    request = [DFObjectManager
               requestWithObject:objects
               method:requestMethod
               path:path
               parameters:parameters];
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
     DDLogVerbose(@"%@ response received: %@", [self.class description], mappingResult);
     success(mappingResult.array);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     NSError *errorToReturn = error;
     if (operation.HTTPRequestOperation.response.statusCode == 401) {
       // authentication required, user needs to log in again
       [[AppDelegate appDelegate] resetApplication];
     } else if (operation.HTTPRequestOperation.response.statusCode == 404) {
       errorToReturn = [self.class NotFoundError];
     } else {
       errorToReturn = [DFPeanutInvalidField invalidFieldsErrorForError:error];
     }
     DDLogWarn(@"%@ got error: %@", [self.class description], errorToReturn);
     failure(errorToReturn);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:operation];
}

+ (NSError *)NotFoundError
{
  NSError *error = [NSError errorWithDomain:@"com.duffyapp.strand"
                                       code:-404
                                   userInfo:@{NSLocalizedDescriptionKey : @"Not found"}];
  return error;
}


@end
