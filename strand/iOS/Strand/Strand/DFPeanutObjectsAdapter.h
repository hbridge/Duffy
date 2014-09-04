//
//  DFPeanutObjectsAdapter.h
//  Strand
//
//  Created by Henry Bridge on 8/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObjectsResponse.h"
#import "DFNetworkAdapter.h"

typedef void (^DFPeanutObjectsCompletion)(DFPeanutObjectsResponse *response,
                                               NSData *responseHash,
                                               NSError *error);

@interface DFPeanutObjectsAdapter : NSObject

- (void)fetchObjectsAtPath:(NSString *)path
       withCompletionBlock:(DFPeanutObjectsCompletion)completionBlock;

- (void)fetchObjectsAtPath:(NSString *)path
       withCompletionBlock:(DFPeanutObjectsCompletion)completionBlock
                parameters:(NSDictionary *)parameters;

@end
