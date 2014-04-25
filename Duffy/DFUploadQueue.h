//
//  DFUploadQueue.h
//  
//
//  Created by Henry Bridge on 4/17/14.
//
//

#import <Foundation/Foundation.h>

@interface DFUploadQueue : NSObject

/* (NSUInteger)addObjectsFromArray:(NSArray *)objects;
 addNewObjects to the waiting queue.  
 Ensures that added objects are not members of waiting, in progress, or complete
 but does allow objects in cancelled to be added.
 */
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
