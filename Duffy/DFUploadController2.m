//
//  DFUploadController2.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadController2.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import "DFUploadQueue.h"
#import "DFUploadOperation.h"
#import "DFAnalytics.h"
#import "DFStatusBarNotificationManager.h"
#import "NSNotificationCenter+DFThreadingAddons.h"
#import "DFNotificationSharedConstants.h"

@interface DFUploadController2()

@property (atomic, retain) DFUploadQueue *objectIDQueue;
@property (readonly, nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@property (atomic, retain) NSOperationQueue *syncOperationQueue;
@property (atomic, retain) NSOperationQueue *uploadOperationQueue;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundUpdateTask;

@property (nonatomic) unsigned int consecutiveRetryCount;
@property (nonatomic) unsigned int sessionRetryCount;

@end


@implementation DFUploadController2

@synthesize managedObjectContext = _managedObjectContext;

static unsigned int MaxConcurrentUploads = 3;
static unsigned int MaxRetryCount = 5;

// We want the upload controller to be a singleton
static DFUploadController2 *defaultUploadController;
+ (DFUploadController2 *)sharedUploadController {
    if (!defaultUploadController) {
        defaultUploadController = [[super allocWithZone:nil] init];
    }
    return defaultUploadController;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedUploadController];
}


- (id)init
{
    self = [super init];
    if (self) {
        self.objectIDQueue = [[DFUploadQueue alloc] init];
        // Setup operation queues
        self.syncOperationQueue = [[NSOperationQueue alloc] init];
        self.syncOperationQueue.maxConcurrentOperationCount = 1;
        self.uploadOperationQueue = [[NSOperationQueue alloc] init];
        self.uploadOperationQueue.maxConcurrentOperationCount = MaxConcurrentUploads;
    }
    return self;
}


#pragma mark - Public methods

- (void)uploadPhotos:(NSArray *)photos
{
    // convert all DFPhotos to ObjectIDs, which are thread safe, so we can pass them across threads
    NSMutableArray *photoIDs = [[NSMutableArray alloc]  initWithCapacity:photos.count];
    for (DFPhoto *photo in photos) {
        [photoIDs addObject:photo.objectID];
    }
    
    [self addPhotosIDsToQueue:photoIDs];
}

- (void)cancelUploads
{
    NSOperation *cancelOperation = [self cancelAllUploadsOperationWithIsError:NO silent:NO];
    cancelOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
    [self scheduleWithDispatchUploads:NO operation:cancelOperation];
}

- (BOOL)isUploadInProgress
{
    return self.objectIDQueue.numObjectsIncomplete > 0;
}

#pragma mark - Upload scheduling

- (void)addPhotosIDsToQueue:(NSArray *)photoIDs
{
    [self scheduleWithDispatchUploads:YES operation:[NSBlockOperation blockOperationWithBlock:^{
        [self.objectIDQueue addObjectsFromArray:photoIDs];
    }]];
}

- (void)scheduleWithDispatchUploads:(BOOL)dispatchUploadsOnComplete operation:(NSOperation *)operation
{
    if (dispatchUploadsOnComplete) {
        operation.completionBlock = ^{
            [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
        };
    }
    [self.syncOperationQueue addOperation:operation];
}

- (NSOperation *)dispatchUploadsOperation
{
    return [NSBlockOperation blockOperationWithBlock:^{
        [self postStatusUpdate];
        DDLogVerbose(@"Dispatching uploads...");
        if (self.uploadOperationQueue.operationCount >= self.uploadOperationQueue.maxConcurrentOperationCount) {
            DDLogVerbose(@"Already maxed out on operations.");
            return;
        }
        
        [self beginBackgroundUpdateTask];
        NSManagedObjectID *nextPhotoID = [self.objectIDQueue takeNextObject];
        if (nextPhotoID) {
            DDLogVerbose(@"Dispatching %@ on uploadQueue.", nextPhotoID);
            DFUploadOperation *uploadOperation = [[DFUploadOperation alloc] initWithPhotoID:nextPhotoID];
            uploadOperation.completionOperationQueue = self.syncOperationQueue;
            uploadOperation.successBlock = [self uploadSuccessfullBlockForObjectID:nextPhotoID];
            uploadOperation.failureBlock = [self uploadFailureBlockForObjectID:nextPhotoID];
            [self.uploadOperationQueue addOperation:uploadOperation];
            if (self.uploadOperationQueue.operationCount < self.uploadOperationQueue.maxConcurrentOperationCount) {
                [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
            }
        } else {
            //there's nothing else to upload, check to see if everything's complete
            if (self.objectIDQueue.numObjectsIncomplete == 0) {
                [self scheduleWithDispatchUploads:NO operation:[self allUploadsCompleteOperation]];
            }
        }
    }];
}

#pragma mark - Upload operation response handlers

- (DFPhotoUploadOperationSuccessBlock)uploadSuccessfullBlockForObjectID:(NSManagedObjectID *)objectID
{
    DFPhotoUploadOperationSuccessBlock successBlock = ^(NSUInteger numBytes){
        DDLogVerbose(@"Upload successful for %@", objectID.description);
        [self.objectIDQueue markObjectCompleted:objectID];
        [self saveUploadedPhotoWithObjectID:objectID];
        self.consecutiveRetryCount = 0;
        [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
    };
    return successBlock;
}

- (void)saveUploadedPhotoWithObjectID:(NSManagedObjectID *)objectID
{
    DFPhoto *photo = (DFPhoto*)[self.managedObjectContext objectWithID:objectID];
    photo.uploadDate = [NSDate date];
    [self saveContext];
    
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFPhotoChangedNotificationName
                                                                  object:self
                                                                userInfo:@{objectID : DFPhotoChangeTypeMetadata}];
}

- (DFPhotoUploadOperationFailureBlock)uploadFailureBlockForObjectID:(NSManagedObjectID *)objectID
{
    DFPhotoUploadOperationFailureBlock failureBlock = ^(NSError *error){
        DDLogVerbose(@"Upload failed for %@", objectID.description);
        if ([self isErrorRetryable:error] && self.consecutiveRetryCount < MaxRetryCount) {
            DDLogVerbose(@"Error retryable.  Moving to back of queue.");
            [self.objectIDQueue moveInProgressObjectBackToQueue:objectID];
            self.consecutiveRetryCount++;
            self.sessionRetryCount++;
        } else {
            NSOperation *cancelOperation = [self cancelAllUploadsOperationWithIsError:YES silent:NO];
            [cancelOperation start];
        }
        
        [self.syncOperationQueue addOperation:[self dispatchUploadsOperation]];
    };
    return failureBlock;
}

- (BOOL)isErrorRetryable:(NSError *)error
{
    //-1001 = timeout, -1021 = request body stream exhausted
    if (error.code == -1001 || error.code == -1021) {
        return YES;
    }
    
    return NO;
}

#pragma mark - End of uploads

- (NSOperation *)cancelAllUploadsOperationWithIsError:(BOOL)isError silent:(BOOL)isSilent
{
    return [NSBlockOperation blockOperationWithBlock:^{
        DDLogInfo(@"Cancelling all operations with isError:%@ isSilent%@",
                  isError ? @"true" : @"false",
                  isSilent ? @"true" : @"false");
        [self.objectIDQueue removeAllObjects];
        [self.uploadOperationQueue cancelAllOperations];
        
        if (!isSilent){
            if (isError) {
                [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateError
                                                                                            numRemaining:0
                                                                                                progress:0.0];
            } else {
                [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateCancelled
                                                                                            numRemaining:0
                                                                                                progress:0.0];
            }
            [DFAnalytics logUploadCancelledWithIsError:isError];
        }
        [self endBackgroundUpdateTask];
    }];
}

- (NSOperation *)allUploadsCompleteOperation
{
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        DDLogInfo(@"All uploads complete.");
        self.consecutiveRetryCount = 0;
        self.sessionRetryCount = 0;
        [self endBackgroundUpdateTask];
    }];
    
    operation.queuePriority = NSOperationQueuePriorityHigh;
    return operation;
}

#pragma mark - Misc helpers

- (void)postStatusUpdate
{
    DFUploadSessionStats *currentStats = [self currentSessionStats];
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFUploadStatusNotificationName
                                                                  object:self
                                                                userInfo:@{DFUploadStatusUpdateSessionUserInfoKey: currentStats}];
    
    if (self.currentSessionStats.numRemaining > 0) {
        [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateProgress
                                                                                    numRemaining:currentStats.numRemaining
                                                                                        progress:currentStats.progress];
    } else if (self.currentSessionStats.numRemaining == 0 && self.currentSessionStats.numUploaded > 0) {
        [[DFStatusBarNotificationManager sharedInstance] showUploadStatusBarNotificationWithType:DFStatusUpdateComplete
                                                                                    numRemaining:currentStats.numRemaining
                                                                                        progress:currentStats.progress];
    }
    
    DDLogInfo(@"%@", currentStats.description);
}

- (DFUploadSessionStats *)currentSessionStats
{
    DFUploadSessionStats *stats = [[DFUploadSessionStats alloc] init];
    stats.numAcceptedUploads = self.objectIDQueue.numTotalObjects;
    stats.numUploaded = self.objectIDQueue.numObjectsComplete;
    stats.numConsecutiveRetries = self.consecutiveRetryCount;
    stats.numTotalRetries = self.sessionRetryCount;
    
    return stats;
}

#pragma mark - Core Data helpers


- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [DFPhotoStore persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

- (void)saveContext
{
    NSError *error = nil;
    if(![self.managedObjectContext save:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [NSException raise:@"Could not save upload photo progress." format:@"Error: %@",[error localizedDescription]];
    }
}


# pragma mark - Background task helpes

- (void) beginBackgroundUpdateTask
{
    if (self.backgroundUpdateTask != UIBackgroundTaskInvalid) {
        return;
    }
    self.backgroundUpdateTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        DDLogInfo(@"Background upload task about to expire.  Cancelling uploads...");
        
        // By cancel will throw an exception on the main thread because it could block.  That's the behavior
        // we want here so we create a semaphore an wait on it.
        NSOperation *cancelOperation = [self cancelAllUploadsOperationWithIsError:NO silent:YES];
        cancelOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
        [self scheduleWithDispatchUploads:NO operation:cancelOperation];
        // the cancel operation ends the background task
    }];
}

- (void) endBackgroundUpdateTask
{
    DDLogInfo(@"Ending background update task.");
    [[UIApplication sharedApplication] endBackgroundTask: self.backgroundUpdateTask];
    self.backgroundUpdateTask = UIBackgroundTaskInvalid;
}



@end
