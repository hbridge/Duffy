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

@end
