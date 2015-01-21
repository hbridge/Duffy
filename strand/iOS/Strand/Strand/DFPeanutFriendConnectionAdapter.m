//
//  DFPeanutFriendConnectionAdapter.m
//  Strand
//
//  Created by Derek Parham on 1/21/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFPeanutFriendConnectionAdapter.h"

@implementation DFPeanutFriendConnectionAdapter


NSString *const FriendConnectionBasePath = @"friend_connection/";

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  return [super responseDescriptorsForPeanutObjectClass:[DFPeanutFriendConnection class]
                                               basePath:FriendConnectionBasePath
                                            bulkKeyPath:@"friend_connections"];
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutFriendConnection class]
                                       bulkPostKeyPath:@"friend_connections"];
}

- (void)deleteFriendConnection:(DFPeanutFriendConnection *)friendConnection
                    success:(DFPeanutRestFetchSuccess)success
                    failure:(DFPeanutRestFetchFailure)failure
{
  [super
   performRequest:RKRequestMethodDELETE
   withPath:FriendConnectionBasePath
   objects:@[friendConnection]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}

- (void)createFriendConnections:(NSArray *)friendConnections
                     success:(DFPeanutRestFetchSuccess)success
                     failure:(DFPeanutRestFetchFailure)failure {
  [super
   performRequest:RKRequestMethodPOST
   withPath:FriendConnectionBasePath
   objects:friendConnections
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
  
}

@end
