//
//  DFNearbyFriendsAdapter.m
//  Strand
//
//  Created by Henry Bridge on 7/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNearbyFriendsAdapter.h"
#import "DFObjectManager.h"
#import "RestKit/RestKit.h"

NSString *const NearbyFriendsPath = @"get_nearby_friends_message";
NSString *const LatitudeKey = @"lat";
NSString *const LongitudeKey = @"lon";
NSString *const AccuracyKey = @"accuracy";

@implementation DFNearbyFriendsAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  RKResponseDescriptor *responseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutMessageResponse objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:NearbyFriendsPath
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  
  return [NSArray arrayWithObjects:responseDescriptor, nil];
}

+ (NSArray *)requestDescriptors
{
  return nil;
}

- (void)fetchNearbyFriendsMessageForLocation:(CLLocation *)location
                             completionBlock:(DFPeanutNearbyFriendsCompletionBlock)completionBlock
{
  NSURLRequest *getRequest = [DFObjectManager
                              requestWithObject:[[DFPeanutMessageResponse alloc] init]
                              method:RKRequestMethodGET
                              path:NearbyFriendsPath
                              parameters:@{
                                           LatitudeKey : @(location.coordinate.latitude),
                                           LongitudeKey: @(location.coordinate.longitude),
                                           AccuracyKey: @(location.horizontalAccuracy),
                                           }];
  DDLogVerbose(@"%@ getting endpoint: %@", [[self class] description], getRequest.URL.absoluteString);
  
  RKObjectRequestOperation *requestOp =
  [[DFObjectManager sharedManager]
   objectRequestOperationWithRequest:getRequest
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
   {
     DFPeanutMessageResponse *response = mappingResult.firstObject;
     if (response.result) {
       completionBlock(response, nil);
     } else {
       NSError *error = [NSError errorWithDomain:@"com.duffyapp.strand"
                                            code:-9
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                     response.invalid_fields.description}];
       DDLogWarn(@"%@ get failed. Error: %@", [[self class] description], error.description);
       completionBlock(response, error);
     }
   }
   failure:^(RKObjectRequestOperation *operation, NSError *error)
   {
     DDLogWarn(@"%@ get failed.  Error: %@", [[self class] description], error.description);
     completionBlock(nil, error);
   }];
  
  [[DFObjectManager sharedManager] enqueueObjectRequestOperation:requestOp];
}


@end
