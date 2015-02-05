//
//  DFPeanutObjectsAdapter.m
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <EKMapper.h>

#import "DFPeanutObjectsAdapter.h"
#import "DFObjectManager.h"
#import "DFDataHasher.h"
#import "DFNetworkingConstants.h"
#import "DFUser.h"
#import "DFAppInfo.h"


@implementation DFPeanutObjectsAdapter


- (void)fetchObjectsAtPath:(NSString *)path
       withCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
                parameters:(NSDictionary *)parameters
{
  if ([[DFUser currentUser] isUserDeveloper]) {
    [self fetchObjectsWithEMAtPath:path withCompletionBlock:completionBlock parameters:parameters];
  } else {
    [self fetchObjectsWithRKAtPath:path withCompletionBlock:completionBlock parameters:parameters];
  }
}

- (void)fetchObjectsWithRKAtPath:(NSString *)path
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


- (void)fetchObjectsWithEMAtPath:(NSString *)path
       withCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
                parameters:(NSDictionary *)parameters
{
  NSURLComponents *components = [[NSURLComponents alloc] init];
  components.scheme = DFServerScheme;
  components.host = DFServerBaseHost;
  components.path = [DFServerAPIPath stringByAppendingString:path];
  
  NSMutableDictionary *allParameters = [self cumulativeParameters];
  [allParameters addEntriesFromDictionary:parameters];
  
  NSMutableArray *queryItems = [NSMutableArray new];
  for (NSString *key in allParameters) {
    NSURLQueryItem *item = [NSURLQueryItem queryItemWithName:key value:[NSString stringWithFormat:@"%@",allParameters[key]]];
    [queryItems addObject:item];
  }
  components.queryItems = queryItems;
  
  DDLogVerbose(@"Fetching url: %@", components.URL);
  
  NSURLSession *session = [NSURLSession sharedSession];
  [[session dataTaskWithURL:components.URL
          completionHandler:^(NSData *data,
                              NSURLResponse *response,
                              NSError *error) {
            NSError *jsonError = nil;
            NSDictionary *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
            
            if (jsonError != nil) {
              DDLogError(@"Error parsing JSON: %@", jsonError);
              completionBlock(nil, nil, error);
            } else {
              DFPeanutObjectsResponse *response = [EKMapper objectFromExternalRepresentation:jsonArray withMapping:[DFPeanutObjectsResponse objectMapping]];
              
              NSData *responseHash = [DFDataHasher
                                      hashDataForData:data
                                      maxLength:data.length];
              
              completionBlock(response, responseHash, error);
            }
          }] resume];
}

- (NSMutableDictionary *)cumulativeParameters
{
  NSMutableDictionary *cumulativeParameters = [[NSMutableDictionary alloc] init];
  if ([[DFUser currentUser] userID]) {
    cumulativeParameters[DFUserIDParameterKey] = [NSNumber numberWithUnsignedLongLong:
                                                  [[DFUser currentUser] userID]];
  }
  if (([[DFUser currentUser] authToken])) {
    cumulativeParameters[DFAuthTokenParameterKey] = [[DFUser currentUser] authToken];
  }
  
  [cumulativeParameters addEntriesFromDictionary:@{
                                                   BuildOSKey: [DFAppInfo deviceAndOSVersion],
                                                   BuildNumberKey: [DFAppInfo buildNumber],
                                                   BuildIDKey: [DFAppInfo buildID],
                                                   }];
  
  return cumulativeParameters;
}

- (void)fetchObjectsAtPath:(NSString *)path
       withCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
{
  [self fetchObjectsAtPath:path withCompletionBlock:completionBlock parameters:nil];
}

@end
