//
//  DFPeanutActionAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutAction.h"
#import "DFPeanutRestEndpointAdapter.h"

extern NSString *const ActionBasePath;

@interface DFPeanutActionAdapter : DFPeanutRestEndpointAdapter <DFNetworkAdapter>

- (void)addAction:(DFPeanutAction *)action
          success:(DFPeanutRestFetchSuccess)success
          failure:(DFPeanutRestFetchFailure)failure;

@end
