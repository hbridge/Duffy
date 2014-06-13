//
//  DFPeanutNewPhotosAdapter.h
//  Strand
//
//  Created by Henry Bridge on 6/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutSearchResponse.h"

typedef void (^DFPeanutNewPhotosCompletionBlock)(DFPeanutSearchResponse *response);


@interface DFPeanutNewPhotosAdapter : NSObject <DFNetworkAdapter>

- (void)fetchNewPhotosAfterDate:(NSString *)startDateTime
                completionBlock:(DFPeanutNewPhotosCompletionBlock)completionBlock;

@end
