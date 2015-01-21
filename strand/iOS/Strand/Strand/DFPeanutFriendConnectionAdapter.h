//
//  DFPeanutFriendConnectionAdapter.h
//  Strand
//
//  Created by Derek Parham on 1/21/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutRestEndpointAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutFriendConnection.h"

@interface DFPeanutFriendConnectionAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)deleteFriendConnection:(DFPeanutFriendConnection *)friendConnection
                       success:(DFPeanutRestFetchSuccess)success
                       failure:(DFPeanutRestFetchFailure)failure;

- (void)createFriendConnections:(NSArray *)friendConnections
                       success:(DFPeanutRestFetchSuccess)success
                       failure:(DFPeanutRestFetchFailure)failure;

@end
