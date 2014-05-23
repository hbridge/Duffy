//
//  DFAutocompleteAdapter.m
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAutocompleteAdapter.h"
#import <RestKit/RestKit.h>
#import "DFObjectManager.h"
#import "DFPeanutAutocompleteResponse.h"
#import "DFObjectManager.h"
#import "DFNetworkingConstants.h"
#import "DFUser.h"


NSString *const AutocompletePathPattern = @"autocomplete";

@implementation DFAutocompleteAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *autocompleteResposeDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutAutocompleteResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:AutocompletePathPattern
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  

  return [NSArray arrayWithObjects:autocompleteResposeDescriptor, nil];
}


- (void)fetchResultsForQuery:(NSString *)query
         withCompletionBlock:(DFAutocompleteFetchCompletionBlock)completionBlock
{
  NSURLRequest *getRequest = [self autocompleteGetRequestForQuery:query];
  
  RKObjectRequestOperation *operation =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFPeanutAutocompleteResponse *response = mappingResult.firstObject;
     completionBlock(response.results);
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"Autocomplete fetch failed.  Error: %@", error.localizedDescription);
     completionBlock(nil);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:operation];
}

- (NSMutableURLRequest *)autocompleteGetRequestForQuery:(NSString *)query
{
  NSMutableURLRequest *request = [DFObjectManager
                                  requestWithObject:[[DFPeanutAutocompleteResponse alloc] init]
                                  method:RKRequestMethodGET
                                  path:AutocompletePathPattern
                                  parameters:@{@"q": query}];
  return request;
}


@end
