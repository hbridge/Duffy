//
//  DFPeanutShareInstanceAdapter.h
//  Strand
//
//  Created by Derek Parham on 12/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutRestEndpointAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutShareInstance.h"

@interface DFPeanutShareInstanceAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)createShareInstance:(DFPeanutShareInstance *)shareInstance
                    success:(DFPeanutRestFetchSuccess)success
                    failure:(DFPeanutRestFetchFailure)failure;

@end
