//
//  DFUploadQueue.m
//  
//
//  Created by Henry Bridge on 4/17/14.
//
//

#import "DFUploadQueue.h"

@interface DFUploadQueue()

@property (atomic) dispatch_semaphore_t accessLock;
@property (nonatomic, retain) NSMutableOrderedSet *notStartedUploads;
@property (nonatomic, retain) NSMutableOrderedSet *inProgressUploads;
@property (nonatomic, retain) NSMutableOrderedSet *completedUploads;
@property (nonatomic, retain) NSMutableOrderedSet *cancelledUploads;

@end

@implementation DFUploadQueue

- (id)init
{
    self = [super init];
    if (self) {
        self.accessLock = dispatch_semaphore_create(1);
        [self initContainers];
    }
    return self;
}

- (void)initContainers
{
    self.notStartedUploads = [[NSMutableOrderedSet alloc] init];
    self.inProgressUploads = [[NSMutableOrderedSet alloc] init];
    self.completedUploads = [[NSMutableOrderedSet alloc] init];
    self.cancelledUploads = [[NSMutableOrderedSet alloc] init];
}

- (void)getLock
{
    if ([NSThread isMainThread]) {
        [NSException raise:@"Cannot block main thread." format:@"Attempting to access uploadqueue from main thread."];
    }
    dispatch_semaphore_wait(self.accessLock, DISPATCH_TIME_FOREVER);
}

- (void)releaseLock
{
    dispatch_semaphore_signal(self.accessLock);
}

- (NSUInteger)addObjectsFromArray:(NSArray *)objects
{
    [self getLock];
    
    NSMutableOrderedSet *requestedObjects = [[NSMutableOrderedSet alloc] initWithArray:objects];
    [requestedObjects removeObjectsInArray:self.notStartedUploads.array];
    [requestedObjects removeObjectsInArray:self.inProgressUploads.array];
    [requestedObjects removeObjectsInArray:self.completedUploads.array];
    
    [self.notStartedUploads addObjectsFromArray:requestedObjects.array];

    [self releaseLock];
    
    return requestedObjects.count;
}
- (id)takeNextObject
{
    [self getLock];
    
    id object = nil;
    if (self.notStartedUploads.count > 0) {
        object = [self.notStartedUploads objectAtIndex:0];
        [self.notStartedUploads removeObjectAtIndex:0];
        [self.inProgressUploads addObject:object];
    }
    
    [self releaseLock];
    return object;
}

- (id)takeNextObjects:(NSUInteger)count
{
    [self getLock];
    
    NSArray *objects = @[];
    if (self.notStartedUploads.count > 0) {
        NSRange range;
        range.location = 0;
        range.length = MIN(count, self.notStartedUploads.count);
        NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
        objects = [self.notStartedUploads objectsAtIndexes:indexSet];
        [self.notStartedUploads removeObjectsAtIndexes:indexSet];
        [self.inProgressUploads addObjectsFromArray:objects];
    }
    
    
    [self releaseLock];
    return objects;
}

- (void)markObjectCompleted:(id)object
{
    [self getLock];
    
    [self.inProgressUploads removeObject:object];
    [self.completedUploads addObject:object];
    
    [self releaseLock];
}


- (void)markObjectCancelled:(id)object
{
    [self getLock];
    
    [self.inProgressUploads removeObject:object];
    [self.cancelledUploads addObject:object];
    
    [self releaseLock];
}

- (void)moveInProgressObjectBackToQueue:(id)object
{
    [self getLock];
    
    [self.inProgressUploads removeObject:object];
    [self.notStartedUploads addObject:object];
    
    [self releaseLock];
}

- (void)moveInProgressObjectsBackToQueue:(NSArray *)objects
{
    [self getLock];
    
    [self.inProgressUploads removeObjectsInArray:objects];
    [self.notStartedUploads addObjectsFromArray:objects];
    
    [self releaseLock];
}


- (NSArray *)objectsWaiting
{
    return self.notStartedUploads.array;
}

- (NSArray *)objectsInProgress
{
    return self.inProgressUploads.array;
}
- (NSArray *)completedObjects
{
    return self.completedUploads.array;
}

- (NSUInteger)numObjectsIncomplete
{
    return self.notStartedUploads.count + self.inProgressUploads.count;
}

- (NSUInteger)numTotalObjects
{
    return self.notStartedUploads.count + self.inProgressUploads.count + self.completedUploads.count;
}

- (NSUInteger)numObjectsComplete
{
    return self.completedUploads.count;
}

- (void)removeAllObjects
{
    [self getLock];
    [self initContainers];
    [self releaseLock];
}

- (void)clearCompleted
{
    [self getLock];
    self.completedUploads = [[NSMutableOrderedSet alloc] init];
    [self releaseLock];
}

@end
