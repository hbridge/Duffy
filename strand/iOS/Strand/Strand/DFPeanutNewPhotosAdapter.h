//
//  DFPeanutNewPhotosAdapter.h
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutObjectsResponse.h"

typedef void (^DFPeanutNewPhotosCompletionBlock)(DFPeanutObjectsResponse *response);


@interface DFPeanutNewPhotosAdapter : NSObject <DFNetworkAdapter>

- (void)fetchNewPhotosAfterDate:(NSDate *)date
                completionBlock:(DFPeanutNewPhotosCompletionBlock)completionBlock;

@end
