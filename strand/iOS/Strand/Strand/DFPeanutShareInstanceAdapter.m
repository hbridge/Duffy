//
//  DFPeanutShareInstanceAdapter.m
//  Strand
//
//  Created by Henry Bridge on 12/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutShareInstanceAdapter.h"

@implementation DFPeanutShareInstanceAdapter

NSString *const ShareInstancedBasePath = @"share_instance/";

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  return [super responseDescriptorsForPeanutObjectClass:[DFPeanutShareInstance class]
                                        basePath:ShareInstancedBasePath
                                     bulkKeyPath:@"share_instances"];
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutShareInstance class]
                                       bulkPostKeyPath:@"share_instances"];
}

- (void)createShareInstances:(NSArray *)shareInstances
                   success:(DFPeanutRestFetchSuccess)success
                   failure:(DFPeanutRestFetchFailure)failure
{
  [super
   performRequest:RKRequestMethodPOST
   withPath:ShareInstancedBasePath
   objects:shareInstances
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}

- (void)addUserIDs:(NSArray *)userIDs
toShareInstanceID:(DFShareInstanceIDType)shareInstanceID
        success:(DFPeanutRestFetchSuccess)success
        failure:(DFPeanutRestFetchFailure)failure
{
  // get the old share instance
  DFPeanutShareInstance *requestInstance = [[DFPeanutShareInstance alloc] init];
  requestInstance.id = @(shareInstanceID);
  [super
   performRequest:RKRequestMethodGET
   withPath:ShareInstancedBasePath
   objects:@[requestInstance]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     // add the new IDs
     DFPeanutShareInstance *shareInstance = resultObjects.firstObject;
     NSMutableSet *accumulatedIDs = [[NSMutableSet alloc] initWithArray:shareInstance.users];
     [accumulatedIDs addObjectsFromArray:userIDs];
     shareInstance.users = [accumulatedIDs allObjects];
     
     // patch
     [super
      performRequest:RKRequestMethodPATCH
      withPath:ShareInstancedBasePath
      objects:@[shareInstance]
      parameters:nil
      forceCollection:NO
      success:^(NSArray *resultObjects) {
        success(resultObjects);
      } failure:^(NSError *error) {
        failure(error);
      }];
   } failure:^(NSError *error) {
     failure(error);
   }];
}

- (void)deleteShareInstance:(DFPeanutShareInstance *)shareInstance
                    success:(DFPeanutRestFetchSuccess)success
                    failure:(DFPeanutRestFetchFailure)failure
{
  [super
   performRequest:RKRequestMethodDELETE
   withPath:ShareInstancedBasePath
   objects:@[shareInstance]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}


@end
