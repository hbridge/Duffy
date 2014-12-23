//
//  DFPeanutShareInstanceAdapter.m
//  Strand
//
//  Created by Derek Parham on 12/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutShareInstanceAdapter.h"


NSString *const ShareInstanceBasePath = @"share_instance/";

@implementation DFPeanutShareInstanceAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  NSArray *inviteRestDescriptors =
  [super responseDescriptorsForPeanutObjectClass:[DFPeanutShareInstance class]
                                        basePath:ShareInstanceBasePath
                                     bulkKeyPath:@"share_instances"];
  
  return inviteRestDescriptors;
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutShareInstance class]
                                       bulkPostKeyPath:@"share_instances"];
}

- (void)createShareInstance:(DFPeanutShareInstance *)shareInstance
                   success:(DFPeanutRestFetchSuccess)success
                   failure:(DFPeanutRestFetchFailure)failure
{
  [super
   performRequest:RKRequestMethodPOST
   withPath:ShareInstanceBasePath
   objects:[NSArray arrayWithObject:shareInstance]
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}

@end
