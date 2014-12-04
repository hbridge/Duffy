//
//  DFPeanutSharedStrandAdapter.m
//  Strand
//
//  Created by Derek Parham on 12/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//


#import "DFPeanutSharedStrandAdapter.h"
#import "DFPeanutSharedStrand.h"
#import "DFUser.h"

NSString *const SharedStrandBasePath = @"shared_strand/";

@implementation DFPeanutSharedStrandAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  NSArray *inviteRestDescriptors =
  [super responseDescriptorsForPeanutObjectClass:[DFPeanutSharedStrand class]
                                        basePath:SharedStrandBasePath
                                     bulkKeyPath:@"shared_strand"];
  
  return inviteRestDescriptors;
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutSharedStrand class]
                                       bulkPostKeyPath:@"shared_strand"];
}

- (void)createSharedStrand:(DFPeanutSharedStrand *)sharedStrand
                   success:(DFPeanutRestFetchSuccess)success
                   failure:(DFPeanutRestFetchFailure)failure
{
  [super
   performRequest:RKRequestMethodPOST
   withPath:SharedStrandBasePath
   objects:[NSArray arrayWithObject:sharedStrand]
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}

@end
