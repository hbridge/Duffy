//
//  DFDeferredCompletionScheduler.h
//  Strand
//
//  Created by Henry Bridge on 11/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFDeferredCompletionScheduler : NSObject

typedef id (^DFExecuteOnceBlock)(void);
typedef void (^DFDeferredCompletionBlock)(id);

- (instancetype)initWithMaxOperations:(NSUInteger)maxOperations
                    executionPriority:(dispatch_queue_priority_t)priority;
- (void)enqueueRequestForObject:(id<NSCopying>)requestObject
                   withPriority:(NSOperationQueuePriority)priority
               executeBlockOnce:(DFExecuteOnceBlock)executeOnceBlock
              completionHandler:(DFDeferredCompletionBlock)completionBlock;
- (void)executeDeferredCompletionsWithResult:(id)result
                                  forRequest:(id<NSCopying>)requestObject;


@end
