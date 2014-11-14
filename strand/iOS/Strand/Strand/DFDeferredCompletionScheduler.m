//
//  DFDeferredCompletionScheduler.m
//  Strand
//
//  Created by Henry Bridge on 11/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDeferredCompletionScheduler.h"
#import "UIDevice+DFHelpers.h"

@interface DFDeferredCompletionScheduler()

@property (atomic) dispatch_semaphore_t schedulerSemaphore;
@property (atomic, retain) NSMutableDictionary *requestObjectsToCompletions;
@property (atomic, retain) NSMutableDictionary *requestObjectsToOperations;
@property (nonatomic, retain) NSOperationQueue *operationQueue;
@property (nonatomic) dispatch_queue_priority_t executionPriority;

@end


@implementation DFDeferredCompletionScheduler

- (instancetype)initWithMaxOperations:(NSUInteger)maxOperations
                    executionPriority:(dispatch_queue_priority_t)priority
{
  self = [super init];
  if (self) {
    self.requestObjectsToCompletions = [NSMutableDictionary new];
    self.requestObjectsToOperations = [NSMutableDictionary new];
    self.executionPriority = priority;
    self.schedulerSemaphore = dispatch_semaphore_create(1);
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = maxOperations;
  }
  return self;
}

+ (NSQualityOfService)QueuePriorityToQOS:(dispatch_queue_priority_t)attr {
  if (attr == DISPATCH_QUEUE_PRIORITY_BACKGROUND) {
    return NSQualityOfServiceBackground;
  } else if (attr == DISPATCH_QUEUE_PRIORITY_DEFAULT) {
    return NSQualityOfServiceDefault;
  } else if (attr == DISPATCH_QUEUE_PRIORITY_HIGH) {
    return NSQualityOfServiceUserInitiated;
  } else if (attr == DISPATCH_QUEUE_PRIORITY_LOW) {
    return NSQualityOfServiceUtility;
  } else {
    return NSQualityOfServiceDefault;
  }
}

+ (double)QueuePriorityToThreadPriority:(dispatch_queue_priority_t)priority {
  if (priority == DISPATCH_QUEUE_PRIORITY_BACKGROUND) {
    return 0.1;
  } else if (priority == DISPATCH_QUEUE_PRIORITY_DEFAULT) {
    return 0.5;
  } else if (priority == DISPATCH_QUEUE_PRIORITY_HIGH) {
    return 0.8;
  } else if (priority == DISPATCH_QUEUE_PRIORITY_LOW) {
    return 0.3;
  } else {
    return 0.5;
  }
}


- (void)enqueueRequestForObject:(id<NSCopying>)requestObject
                   withPriority:(NSOperationQueuePriority)priority
               executeBlockOnce:(DFExecuteOnceBlock)executeOnceBlock
              completionHandler:(DFDeferredCompletionBlock)completionBlock;
{
  BOOL callExecuteOnceBlock = NO;
  dispatch_semaphore_wait(self.schedulerSemaphore, DISPATCH_TIME_FOREVER);
  
  // store the completion block for the request
  NSMutableArray *completionBlocksForRequest = self.requestObjectsToCompletions[requestObject];
  DDLogVerbose(@"%@ request: %@ has %d completion blocks ahead in queue.", self.class,
               requestObject,
               (int)completionBlocksForRequest.count);
  if (!completionBlocksForRequest) completionBlocksForRequest = [NSMutableArray new];
  [completionBlocksForRequest addObject:completionBlock];
  self.requestObjectsToCompletions[requestObject] = completionBlocksForRequest;
  
  // figure out if there is an operation for the request in the queue
  // if there are none, we'll need to call the executeOnceBlock at the end
  NSOperation *operation = self.requestObjectsToOperations[requestObject];
  if (operation) {
    // ensure that the queue priority is as high as the highest request
    operation.queuePriority = MAX(operation.queuePriority, priority);
  } else {
    callExecuteOnceBlock = YES;
  }
  
  DFDeferredCompletionScheduler __weak *weakSelf = self;
  NSOperation *executeOnceOperation;
  if (callExecuteOnceBlock) {
    // call the load block
    executeOnceOperation =
    [NSBlockOperation blockOperationWithBlock:^{
      id result = executeOnceBlock();
      DDLogVerbose(@"%@ executeOnceResult: %@", [DFDeferredCompletionScheduler class], result);
      [weakSelf executeDeferredCompletionsWithResult:result forRequest:requestObject];
    }];
    executeOnceOperation.queuePriority = priority;
    [self setOperationPriority:executeOnceOperation];
    self.requestObjectsToOperations[requestObject] = executeOnceOperation;
  }
  
  if (executeOnceOperation) {
    [self.operationQueue addOperation:executeOnceOperation];
  }
  
  dispatch_semaphore_signal(self.schedulerSemaphore);
}

- (void)setOperationPriority:(NSOperation *)operation
{
  if ([UIDevice majorVersionNumber] < 8) {
    operation.threadPriority = [DFDeferredCompletionScheduler
                                QueuePriorityToThreadPriority:self.executionPriority];
  } else {
    operation.qualityOfService = [DFDeferredCompletionScheduler
                                  QueuePriorityToQOS:self.executionPriority];
  }
}

- (void)executeDeferredCompletionsWithResult:(id)result forRequest:(id<NSCopying>)requestObject
{
  dispatch_semaphore_wait(self.schedulerSemaphore, DISPATCH_TIME_FOREVER);
  
  NSMutableArray *deferredHandlers = self.requestObjectsToCompletions[requestObject];
  DDLogVerbose(@"%@ executing %@ blocks for request %@",
               [DFDeferredCompletionScheduler class],
               @(deferredHandlers.count),
               requestObject);
  for (DFDeferredCompletionBlock completionBlock in deferredHandlers) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completionBlock(result);
    });
  }
  [deferredHandlers removeAllObjects];
  [self.requestObjectsToOperations removeObjectForKey:requestObject];

  dispatch_semaphore_signal(self.schedulerSemaphore);
}


@end
