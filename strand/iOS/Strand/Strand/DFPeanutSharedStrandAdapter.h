//
//  DFPeanutSharedStrandAdapter.h
//  Strand
//
//  Created by Derek Parham on 12/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//


#import "DFPeanutRestEndpointAdapter.h"
#import "DFObjectManager.h"
#import "DFPeanutSharedStrand.h"



@interface DFPeanutSharedStrandAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)createSharedStrand:(DFPeanutSharedStrand *)sharedStrand
            success:(DFPeanutRestFetchSuccess)success
            failure:(DFPeanutRestFetchFailure)failure;

@end
