//
//  DFPeanutStrandInviteAdapter.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutRestEndpointAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutStrandInvite.h"
#import "DFPeanutContact.h"
#import "DFPeanutStrand.h"
#import "DFSMSInviteStrandComposeViewController.h"
#import "DFPeanutStrand.h"



@interface DFPeanutStrandInviteAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)postInvites:(NSArray *)peanutStrandInvites
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;

- (void)markInviteWithIDUsed:(NSNumber *)inviteID
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;


/* Helper method, creates peanut invites on the server, and opens an SMS dialog for any users
 that don't have strand yet */
- (void)sendInvitesForStrand:(DFPeanutStrand *)peanutStrandObject
            toPeanutContacts:(NSArray *)peanutContacts
        inviteLocationString:(NSString *)inviteLocationString
            invitedPhotosDate:(NSDate *)invitedPhotosDate
                     success:(void(^)(DFSMSInviteStrandComposeViewController *))success
                     failure:(DFPeanutRestFetchFailure)failure;

@end
