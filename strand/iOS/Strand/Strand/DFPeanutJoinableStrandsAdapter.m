//
//  DFPeanutNearbyClustersAdapter.m
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutJoinableStrandsAdapter.h"
#import <Restkit/RestKit.h>
#import "DFObjectManager.h"
#import "DFPeanutObjectsResponse.h"
#import "DFStrandConstants.h"

NSString *const NearbyClustersPath = @"get_joinable_strands";

NSString *const MaxNumberResultsParameter = @"num";
NSString *const MinDateParameter = @"start_date_time";
NSString *const LatitudeParameter = @"lat";
NSString *const LongitudeParameter = @"lon";


@implementation DFPeanutJoinableStrandsAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *searchResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutObjectsResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:NearbyClustersPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:searchResponseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}



- (void)fetchJoinableStrandsNearLatitude:(double)latitude
                               longitude:(double)longitude
                     completionBlock:(DFPeanutNearbyClustersCompletionBlock)completionBlock
{
  
  if (latitude == 0.0 || longitude == 0.0) {
    completionBlock(nil);
    return;
  }
  
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutObjectsResponse alloc] init]
                              method:RKRequestMethodGET
                              path:NearbyClustersPath
                              parameters:@{
                                           LatitudeParameter : @(latitude),
                                           LongitudeParameter : @(longitude)
                                           }];
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutObjectsResponse class]]){
       DFPeanutObjectsResponse *response = mappingResult.firstObject;
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
