//
//  DFPeanutShareInstanceAdapter.h
//  Strand
//
//  Created by Henry Bridge on 12/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutRestEndpointAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutShareInstance.h"


@interface DFPeanutShareInstanceAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)createShareInstances:(NSArray *)shareInstances
                     success:(DFPeanutRestFetchSuccess)success
                     failure:(DFPeanutRestFetchFailure)failure;

- (void)addUserIDs:(NSArray *)userIDs
 toShareInstanceID:(DFShareInstanceIDType)shareInstanceID
           success:(DFPeanutRestFetchSuccess)success
           failure:(DFPeanutRestFetchFailure)failure;

- (void)deleteShareInstance:(DFPeanutShareInstance *)shareInstance
                    success:(DFPeanutRestFetchSuccess)success
                    failure:(DFPeanutRestFetchFailure)failure;


@end
