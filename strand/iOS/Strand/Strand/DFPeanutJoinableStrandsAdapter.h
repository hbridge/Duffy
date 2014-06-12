//
//  DFPeanutNearbyClustersAdapter.h
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutSearchResponse.h"

typedef void (^DFPeanutNearbyClustersCompletionBlock)(DFPeanutSearchResponse *response);

@interface DFPeanutJoinableStrandsAdapter : NSObject <DFNetworkAdapter>

- (void)fetchJoinableStrandsWithCompletionBlock:(DFPeanutNearbyClustersCompletionBlock)completionBlock;

@end
