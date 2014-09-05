//
//  DFPeanutStrandInviteAdapter.m
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutStrandInviteAdapter.h"
#import "DFPeanutStrandInvite.h"
#import "DFUser.h"

NSString *const StrandInviteBasePath = @"strand_invite/";

@implementation DFPeanutStrandInviteAdapter

+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  NSArray *inviteRestDescriptors =
  [super responseDescriptorsForPeanutObjectClass:[DFPeanutStrandInvite class]
                                        basePath:StrandInviteBasePath
                                     bulkKeyPath:@"invites"];
  
  return inviteRestDescriptors;
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutStrandInvite class]
                                           bulkPostKeyPath:@"invites"];
}

- (void)postInvites:(NSArray *)peanutStrandInvites
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;
{
  [super
   performRequest:RKRequestMethodPOST
   withPath:StrandInviteBasePath
   objects:peanutStrandInvites
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(success);
   } failure:^(NSError *error) {
     failure(failure);
   }];
}



- (void)markInviteWithIDUsed:(NSNumber *)inviteID
                     success:(DFPeanutRestFetchSuccess)success
                     failure:(DFPeanutRestFetchFailure)failure
{
  NSString *invitePath = [[StrandInviteBasePath stringByAppendingPathComponent:[inviteID stringValue]]
                          stringByAppendingString:@"/"];
  DFPeanutStrandInvite *invite = [[DFPeanutStrandInvite alloc] init];
  invite.id = inviteID;
  // get the invite object
  [super
   performRequest:RKRequestMethodGET
   withPath:invitePath
   objects:@[invite]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     DFPeanutStrandInvite *fetchedInvite = resultObjects.firstObject;
     fetchedInvite.accepted_user_id = @([[DFUser currentUser] userID]);
     [super
      performRequest:RKRequestMethodPUT
      withPath:invitePath
      objects:@[fetchedInvite]
      parameters:nil
      forceCollection:NO
      success:^(NSArray *resultObjects) {
        success(resultObjects);
      } failure:^(NSError *error) {
        failure(error);
      }];
   } failure:^(NSError *error) {
     failure(failure);
   }];
}


@end
