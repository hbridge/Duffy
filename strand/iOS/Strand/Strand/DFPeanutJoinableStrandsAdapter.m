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
#import "DFPeanutSearchResponse.h"
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
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutSearchResponse objectMapping]
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



- (void)fetchJoinableStrandsWithCompletionBlock:(DFPeanutNearbyClustersCompletionBlock)completionBlock
{
  NSNumber *lastLatitude = [[NSUserDefaults standardUserDefaults]
                            objectForKey:DFStrandLastKnownLatitudeDefaultsKey];
  NSNumber *lastLongitude = [[NSUserDefaults standardUserDefaults]
                             objectForKey:DFStrandLastKnownLongitudeDefaultsKey];
  
  if (!lastLatitude || !lastLongitude) {
    completionBlock(nil);
    return;
  }
  
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutSearchResponse alloc] init]
                              method:RKRequestMethodGET
                              path:NearbyClustersPath
                              parameters:@{
                                           LatitudeParameter : lastLatitude,
                                           LongitudeParameter : lastLongitude
                                           }];
  DDLogInfo(@"DFPeanutJoinableStrandsAdapter getting endpoint: %@", getRequest.URL.absoluteString);
  
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
