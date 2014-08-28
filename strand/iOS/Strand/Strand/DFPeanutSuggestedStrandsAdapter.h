//
//  DFPeanutSuggestedStrandsAdapter.h
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObjectsAdapter.h"

@interface DFPeanutSuggestedStrandsAdapter : DFPeanutObjectsAdapter <DFNetworkAdapter>

- (void)fetchSuggestedStrandsWithCompletion:(DFPeanutObjectsCompletion)completionBlock;

@end
