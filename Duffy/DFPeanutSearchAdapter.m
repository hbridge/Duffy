//
//  DFPeanutSearchAdapter.m
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutSearchAdapter.h"
#import <RestKit/RestKit.h>
#import "DFPeanutSearchResponse.h"
#import "DFObjectManager.h"


NSString *const SearchPath = @"searchV2";
NSString *const QueryParameter = @"q";
NSString *const MaxNumberResultsParameter = @"num";
NSString *const MinDateParameter = @"start_date_time";
NSString *const DocstackParameter = @"docstack";

@implementation DFPeanutSearchAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *searchResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutSearchResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:SearchPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:searchResponseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}



- (void)fetchSearchResultsForQuery:(NSString *)query
                        maxResults:(NSUInteger)maxResults
                           minDateString:(NSString *)minDateString
               withCompletionBlock:(DFSearchFetchCompletionBlock)completionBlock
{
  if (minDateString == nil) minDateString = @"";
  
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutSearchResponse alloc] init]
                              method:RKRequestMethodGET
                              path:SearchPath
                              parameters:@{
                                           QueryParameter : query,
                                           MaxNumberResultsParameter: @(maxResults),
                                           MinDateParameter : minDateString,
                                           DocstackParameter : [query isEqualToString:@"''"] ? @(1) : @(0),
                                           }];
  DDLogInfo(@"Executing search: %@", getRequest.URL.absoluteString);
  
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
