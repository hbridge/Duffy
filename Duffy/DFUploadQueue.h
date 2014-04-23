//
//  DFUploadQueue.h
//  
//
//  Created by Henry Bridge on 4/17/14.
//
//

#import <Foundation/Foundation.h>

@interface DFUploadQueue : NSObject


- (NSUInteger)addObjectsFromArray:(NSArray *)objects;
- (id)takeNextObject;
- (void)markObjectCompleted:(id)object;
- (void)markObjectCancelled:(id)object;
- (void)moveInProgressObjectBackToQueue:(id)object;

- (NSArray *)objectsWaiting;
- (NSArray *)objectsInProgress;
- (NSArray *)completedObjects;

- (NSUInteger)numTotalObjects;
- (NSUInteger)numObjectsIncomplete;
- (NSUInteger)numObjectsComplete;

- (void)removeAllObjects;
- (void)clearCompleted;

@end
