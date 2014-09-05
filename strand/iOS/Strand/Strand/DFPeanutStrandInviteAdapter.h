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

@interface DFPeanutStrandInviteAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)postInvites:(NSArray *)peanutStrandInvites
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;


- (void)markInviteWithIDUsed:(NSNumber *)inviteID
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;

@end
