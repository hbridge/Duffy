//
//  DFPeanutNewPhotosAdapter.m
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutNewPhotosAdapter.h"
#import <Restkit/RestKit.h>
#import "DFObjectManager.h"
#import "DFPeanutSearchResponse.h"
#import "DFStrandConstants.h"

NSString *const NewPhotosPath = @"get_new_photos";

NSString *const StartDateTimeParameter = @"start_date_time";

@implementation DFPeanutNewPhotosAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *searchResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutSearchResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:NewPhotosPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:searchResponseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}



- (void)fetchNewPhotosAfterDate:(NSString *)startDateTime
                completionBlock:(DFPeanutNewPhotosCompletionBlock)completionBlock
{
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutSearchResponse alloc] init]
                              method:RKRequestMethodGET
                              path:NewPhotosPath
                              parameters:@{
                                           StartDateTimeParameter : startDateTime,
                                           }];
  DDLogInfo(@"DFPeanutNearbyClusters getting endpoint: %@", getRequest.URL.absoluteString);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutSearchResponse class]]){
       DFPeanutSearchResponse *response = mappingResult.firstObject;
       completionBlock(response);
     } else {
       DDLogWarn(@"Search fetch resulted in a non-search response.  Mapping result: %@",
                 mappingResult.description);
       completionBlock(nil);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"Search fetch failed.  Error: %@", error.description);
     completionBlock(nil);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}

@end


