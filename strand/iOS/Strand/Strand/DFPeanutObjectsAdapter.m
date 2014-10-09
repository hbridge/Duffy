//
//  DFPeanutObjectsAdapter.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutObjectsAdapter.h"
#import "DFObjectManager.h"
#import "DFDataHasher.h"

@implementation DFPeanutObjectsAdapter


- (void)fetchObjectsAtPath:(NSString *)path
       withCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
                parameters:(NSDictionary *)parameters
{
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutObjectsResponse alloc] init]
                              method:RKRequestMethodGET
                              path:path
                              parameters:parameters
                              ];
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     NSData *responseHash = [DFDataHasher
                             hashDataForData:operation.HTTPRequestOperation.responseData
                             maxLength:operation.HTTPRequestOperation.responseData.length];
     if ([[mappingResult.firstObject class] isSubclassOfClass:[DFPeanutObjectsResponse class]]){
       DFPeanutObjectsResponse *response = mappingResult.firstObject;
       completionBlock(response, responseHash, nil);
     } else {
       NSError *error = [NSError
                         errorWithDomain:@"com.duffyapp.strand"
                         code:-12
                         userInfo:@{
                                    NSLocalizedDescriptionKey: @"Error. Please submit an error report to support.",
                                    NSLocalizedFailureReasonErrorKey: @"Search fetch resulted in a non-search response.",
                                    @"MappingResult": mappingResult.description,
                                    }];
       DDLogWarn(@"%@", error.description);
       completionBlock(nil, nil, error);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"Search fetch failed.  Error: %@", error.description);
     completionBlock(nil,nil, error);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}

- (void)fetchObjectsAtPath:(NSString *)path
       withCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
{
  [self fetchObjectsAtPath:path withCompletionBlock:completionBlock parameters:nil];
}

@end
