//
//  DFPeanutGalleryAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutSearchResponse.h"

typedef void (^DFPeanutGalleryCompletionBlock)(DFPeanutSearchResponse *response);

@interface DFPeanutGalleryAdapter : NSObject <DFNetworkAdapter>

- (void)fetchGalleryWithCompletionBlock:(DFPeanutGalleryCompletionBlock)completionBlock;

@end
