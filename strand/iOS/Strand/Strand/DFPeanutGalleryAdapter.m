//
//  DFPeanutGalleryAdapter.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutGalleryAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutSearchResponse.h"
#import "DFDataHasher.h"

NSString *const GalleryPath = @"neighbors";

@implementation DFPeanutGalleryAdapter 


+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *galleryResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutSearchResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:GalleryPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:galleryResponseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}


- (void)fetchGalleryWithCompletionBlock:(DFPeanutGalleryCompletionBlock)completionBlock
{
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutSearchResponse alloc] init]
                              method:RKRequestMethodGET
                              path:GalleryPath
                              parameters:nil
                              ];
  DDLogVerbose(@"%@ getting endpoint: %@", [self class], getRequest.URL.absoluteString);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     NSData *responseHash = [DFDataHasher
                             hashDataForData:operation.HTTPRequestOperation.responseData];
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutSearchResponse class]]){
       DFPeanutSearchResponse *response = mappingResult.firstObject;
       completionBlock(response, responseHash);
     } else {
       DDLogWarn(@"Search fetch resulted in a non-search response.  Mapping result: %@",
                 mappingResult.description);
       completionBlock(nil, nil);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"Search fetch failed.  Error: %@", error.description);
     completionBlock(nil,nil);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}


@end
