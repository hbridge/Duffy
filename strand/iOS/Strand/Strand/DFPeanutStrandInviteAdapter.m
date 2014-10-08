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
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}



- (void)markInviteWithIDUsed:(NSNumber *)inviteID
                     success:(DFPeanutRestFetchSuccess)success
                     failure:(DFPeanutRestFetchFailure)failure
{
  DFPeanutStrandInvite *invite = [[DFPeanutStrandInvite alloc] init];
  invite.id = inviteID;
  // get the invite object
  [super
   performRequest:RKRequestMethodGET
   withPath:StrandInviteBasePath
   objects:@[invite]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     DFPeanutStrandInvite *fetchedInvite = resultObjects.firstObject;
     fetchedInvite.accepted_user = @([[DFUser currentUser] userID]);
     [super
      performRequest:RKRequestMethodPUT
      withPath:StrandInviteBasePath
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

- (void)sendInvitesForStrand:(DFPeanutStrand *)peanutStrand
            toPeanutContacts:(NSArray *)peanutContacts
        inviteLocationString:(NSString *)inviteLocationString
            inviteDateString:(NSString *)inviteDateString
                     success:(void(^)(DFSMSInviteStrandComposeViewController *))success
                     failure:(DFPeanutRestFetchFailure)failure
{
  NSMutableArray *invites = [NSMutableArray new];
  for (DFPeanutContact *contact in peanutContacts) {
    DFPeanutStrandInvite *invite = [[DFPeanutStrandInvite alloc] init];
    invite.user = @([[DFUser currentUser] userID]);
    invite.strand = peanutStrand.id;
    invite.phone_number = contact.phone_number;
    [invites addObject:invite];
  }
  [self postInvites:invites success:^(NSArray *resultObjects) {
    NSMutableArray *numbersToSMS = [NSMutableArray new];
    for (DFPeanutStrandInvite *invite in resultObjects) {
      if (!invite.invited_user) {
        [numbersToSMS addObject:invite.phone_number];
      }
    }
    
    if (numbersToSMS.count > 0) {
      DFSMSInviteStrandComposeViewController *smsInviteVC = [[DFSMSInviteStrandComposeViewController alloc]
                                                             initWithRecipients:numbersToSMS
                                                             locationString:inviteLocationString
                                                             dateString:inviteDateString];
      success(smsInviteVC);
    } else {
      success(nil);
    }
  } failure:^(NSError *error) {
    failure(error);
  }];

}



@end
