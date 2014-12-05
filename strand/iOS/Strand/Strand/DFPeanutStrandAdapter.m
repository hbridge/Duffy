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
#import "DFPeanutFeedObject.h"
#import "DFPeanutTrueFalseResponse.h"

NSString *const RestStrandPath = @"strands/:id/";
NSString *const CreateStrandPath = @"strands/";

NSString *const AddPhotosPath = @"add_photos_to_strand";

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
  RKResponseDescriptor *addPhotosSuccessResponse =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutTrueFalseResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:AddPhotosPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  return @[restSuccessResponse, restErrorResponse, createSuccessResponse, createErrorResponse, addPhotosSuccessResponse];
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

/*
 
 This is old code to patch a strand with new photos.  Leaving here incase we need it, but if here after Dec 10th, 2014, delete
 TODO(Derek): Look at this if needed
 
 // first get the strand
 [self
 performRequest:RKRequestMethodGET
 withPeanutStrand:reqStrand success:^(DFPeanutStrand *peanutStrand) {
 //remove the photo from the strand's list of photos
 NSMutableArray *newPhotosList = [peanutStrand.photos mutableCopy];
 [newPhotosList addObjectsFromArray:photoIDs];
 peanutStrand.photos = newPhotosList;
 
 // patch the strand with the new list
 [self
 performRequest:RKRequestMethodPATCH
 withPeanutStrand:peanutStrand success:^(DFPeanutStrand *peanutStrand) {
 DDLogInfo(@"%@ added photos %@ to %@", self.class, photoIDs, peanutStrand);
 if (success) success();
 } failure:^(NSError *error) {
 DDLogError(@"%@ couldn't patch strand: %@", self.class, error);
 if (failure) failure(error);
 }];
 } failure:^(NSError *error) {
 DDLogError(@"%@ couldn't get strand: %@", self.class, error);
 failure(error);
 }];
 }
 
 
 - (void)fetchNewPhotosAfterDate:(NSDate *)date
 completionBlock:(DFPeanutNewPhotosCompletionBlock)completionBlock
 {*/


- (void)addPhotos:(NSArray *)photoObjects
      toStrandID:(DFStrandIDType)strandID
         success:(DFSuccessBlock)success
         failure:(DFFailureBlock)failure
{
  DFPeanutStrand *reqStrand = [[DFPeanutStrand alloc] init];
  reqStrand.id = @(strandID);
  
  NSMutableArray *photoIDs = [NSMutableArray new];
  [photoIDs addObjectsFromArray:[photoObjects arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *photoObject) {
    return @(photoObject.id);
  }]];
  
  DDLogInfo(@"Going to add photos %@ to strand %llu", photoIDs, strandID);

  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutTrueFalseResponse alloc] init]
                              method:RKRequestMethodGET
                              path:AddPhotosPath
                              parameters:@{
                                           @"strand_id" : @(strandID),
                                           @"photo_ids" : photoIDs
                                           }];
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutTrueFalseResponse class]]){
       DFPeanutTrueFalseResponse *response = mappingResult.firstObject;
       if (response.result) {
         if (success) success();
       } else {
         DDLogWarn(@"Adding photos returned a false response: %@",
                   mappingResult.description);
         if (failure) failure(nil);
       }
     } else {
       DDLogWarn(@"Adding photos returned a non boolean response: %@",
                 mappingResult.description);
       if (failure) failure(nil);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"Adding photos failed failed.  Error: %@", error.description);
     if (failure) failure(error);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}


@end
