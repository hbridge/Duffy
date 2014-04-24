//
//  DFUploadController.m
//  Duffy
//
//  Created by Henry Bridge on 3/11/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <RestKit/RestKit.h>
#import <CommonCrypto/CommonHMAC.h>
#import <JDStatusBarNotification/JDStatusBarNotification.h>
#import "DFUploadController.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import "DFUser.h"
#import "DFSettingsViewController.h"
#import "NSDictionary+DFJSON.h"
#import "DFPhoto+FaceDetection.h"
#import "NSNotificationCenter+DFThreadingAddons.h"
#import "DFNotificationSharedConstants.h"
#import "DFAnalytics.h"
#import "DFPhotoUploadAdapter.h"
#import "DFUploadQueue.h"




@interface DFUploadController()

@property (atomic, retain) DFPhotoUploadAdapter *uploadAdapter;
@property (atomic) dispatch_queue_t dispatchQueue;
@property (atomic, retain) DFUploadQueue *uploadURLQueue;
@property (atomic) unsigned int numUploadOperations;
@property (atomic) unsigned int consecutiveRetryCount;
@property (atomic) unsigned int sessionRetryCount;
@property (atomic) dispatch_semaphore_t saveSemaphore;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundUpdateTask;


@property (readonly, nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@end

@implementation DFUploadController

@synthesize managedObjectContext = _managedObjectContext;



static const unsigned int MaxSimultaneousUploads = 2;
static const unsigned int MaxConsecutiveRetries = 5;


typedef enum {
    DFStatusUpdateProgress,
    DFStatusUpdateComplete,
    DFStatusUpdateError,
    DFStatusUpdateCancelled,
    DFStatusUpdateResumed,
} DFStatusUpdateType;

// We want the upload controller to be a singleton
static DFUploadController *defaultUploadController;
+ (DFUploadController *)sharedUploadController {
    if (!defaultUploadController) {
        defaultUploadController = [[super allocWithZone:nil] init];
    }
    return defaultUploadController;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedUploadController];
}

- (DFUploadController *)init
{
    self = [super init];
    if (self) {
        self.dispatchQueue = dispatch_queue_create("com.duffyapp.DFUploadController.dispatchQueue", DISPATCH_QUEUE_CONCURRENT);
        self.saveSemaphore = dispatch_semaphore_create(1);
        self.uploadURLQueue = [[DFUploadQueue alloc] init];
        [self setupStatusBarNotifications];
        self.backgroundUpdateTask = UIBackgroundTaskInvalid;
        self.uploadAdapter = [[DFPhotoUploadAdapter alloc] init];
    }
    return self;
}

- (DFUploadSessionStats *)currentSessionStats
{
    DFUploadSessionStats *stats = [[DFUploadSessionStats alloc] init];
    stats.numAcceptedUploads = self.uploadURLQueue.numTotalObjects;
    stats.numUploaded = self.uploadURLQueue.numObjectsComplete;
    stats.numConsecutiveRetries = self.consecutiveRetryCount;
    stats.numTotalRetries = self.sessionRetryCount;
    
    return stats;
}

#pragma mark - Public APIs

- (void)uploadPhotos:(NSArray *)photos
{
    NSUInteger photosInQueuePreAdd = self.uploadURLQueue.numObjectsIncomplete;
    if (photos.count < 1) return;
 
    //TODO may get more background time if we call this on app background
    [self beginBackgroundUpdateTask];
    
    NSMutableOrderedSet *photoURLStrings = [[NSMutableOrderedSet alloc] init];
    for (DFPhoto *photo in photos) {
        [photoURLStrings addObject:photo.alAssetURLString];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger numAdded = [self.uploadURLQueue addObjectsFromArray:photoURLStrings.array];
        
        DDLogInfo(@"UploadController: upload requested for %d photos, %d already in queue, %d added.",
              (int)photos.count,
              (int)photosInQueuePreAdd,
              (int)numAdded
              );
        
        if (numAdded > 0) [self uploadQueueChanged];
    });
}

- (void)cancelUpload
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self cancelUploadsWithIsError:NO silent:NO];
    });
}

- (BOOL)isUploadInProgress
{
    return (self.uploadURLQueue.numObjectsIncomplete > 0);
}

#pragma mark - Private config code
- (void)setupStatusBarNotifications
{
    [JDStatusBarNotification setDefaultStyle:^JDStatusBarStyle *(JDStatusBarStyle *style) {
        style.barColor = [UIColor colorWithWhite:.9686 alpha:1.0]; //.9686 matches the default nav bar color
        style.textColor = [UIColor darkGrayColor];
        style.progressBarColor = [UIColor blueColor];
        style.animationType = JDStatusBarAnimationTypeFade;
        return style;
    }];
}

#pragma mark - Private Uploading Code

- (void)uploadQueueChanged
{
    [self postStatusUpdate];
    
    if (self.uploadURLQueue.objectsWaiting.count > 0) {
        dispatch_async(self.dispatchQueue, ^{
            if (self.numUploadOperations >= MaxSimultaneousUploads) {
                return;
            }
            
            while (self.numUploadOperations < MaxSimultaneousUploads){
                self.numUploadOperations++;
                
                NSString *photoURLString = [self.uploadURLQueue takeNextObject];
                if (!photoURLString) {
                    self.numUploadOperations--;
                    break;
                }
                DFPhoto *photo = [DFPhoto photoWithURL:photoURLString inContext:self.managedObjectContext];
                if (photo == nil) {
                    [self.uploadURLQueue markObjectCancelled:photoURLString];
                    self.numUploadOperations--;
                    [self uploadQueueChanged];
                    break;
                }
                
                
                [DFAnalytics logUploadBegan];
                [self.uploadAdapter uploadPhoto:photo withSuccessBlock:^(NSUInteger numBytes){
                    dispatch_async(self.dispatchQueue, ^{
                        self.numUploadOperations--;
                        [DFAnalytics logUploadEndedWithResult:DFAnalyticsValueResultSuccess numImageBytes:numBytes];
                        [self uploadFinishedForPhoto:photo];
                    });
                } failureBlock:^(NSError *error) {
                    dispatch_async(self.dispatchQueue, ^{
                        self.numUploadOperations--;
                        NSString *debugString = [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code];
                        [DFAnalytics logUploadEndedWithResult:DFAnalyticsValueResultFailure debug:debugString];
                        
                        if ([self isErrorRetryable:error]) {
                            [self retryUploadPhoto:photo];
                        } else {
                            [self cancelUploadsWithIsError:YES silent:NO];
                        }
                    });
                }];
            }
        });
    } else if (self.uploadURLQueue.numObjectsIncomplete == 0) {
        DDLogInfo(@"No photos remaining.");
        [self.uploadURLQueue clearCompleted];
        [self endBackgroundUpdateTask];
    }
}

- (BOOL)isErrorRetryable:(NSError *)error
{
    //-1001 = timeout, -1021 = request body stream exhausted
    if (error.code == -1001 || error.code == -1021) {
        return YES;
    }
    
    return NO;
}

- (void)retryUploadPhoto:(DFPhoto *)photo
{
    self.consecutiveRetryCount++;
    self.sessionRetryCount++;
    
    if (self.consecutiveRetryCount > MaxConsecutiveRetries) {
        [self cancelUploadsWithIsError:YES silent:NO];
        [DFAnalytics logUploadRetryCountExceededWithCount:self.consecutiveRetryCount];
    } else {
        [self.uploadURLQueue moveInProgressObjectBackToQueue:photo.alAssetURLString];
        [self uploadQueueChanged];
    }
}

- (void)cancelUploadsWithIsError:(BOOL)isError silent:(BOOL)isSilent
{
    NSUInteger numLeft = self.uploadURLQueue.numObjectsIncomplete;

    DDLogInfo(@"Non-error: canceling all uploads with %lu left.", (unsigned long)numLeft);
    
    if (!isSilent){
        if (isError) {
            [self showStatusBarNotificationWithType:DFStatusUpdateError];
        } else {
            [self showStatusBarNotificationWithType:DFStatusUpdateCancelled];
        }
        [DFAnalytics logUploadCancelledWithIsError:isError];
    }
    
    [self.uploadAdapter cancelAllUploads];
    [self.uploadURLQueue removeAllObjects];
}




# pragma mark - Private Upload Completion Handlers

- (void)uploadFinishedForPhoto:(DFPhoto *)photo
{
    [self saveUploadProgress];
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFPhotoChangedNotificationName
                                                                  object:self
                                                                userInfo:@{photo.objectID : DFPhotoChangeTypeMetadata}];
    
    
    self.consecutiveRetryCount = 0;
    [self.uploadURLQueue markObjectCompleted:photo.alAssetURLString];
    [self uploadQueueChanged];
}

- (void)saveUploadProgress
{
    dispatch_semaphore_wait(self.saveSemaphore, DISPATCH_TIME_FOREVER);
    NSError *error = nil;
    if(![self.managedObjectContext save:&error]) {
        DDLogError(@"Unresolved error %@, %@", error, [error userInfo]);
        [NSException raise:@"Could not save upload photo progress." format:@"Error: %@",[error localizedDescription]];
    }
    dispatch_semaphore_signal(self.saveSemaphore);
}

- (void)postStatusUpdate
{
    [[NSNotificationCenter defaultCenter] postMainThreadNotificationName:DFUploadStatusNotificationName
                                                                  object:self
                                                                userInfo:@{DFUploadStatusUpdateSessionUserInfoKey: self.currentSessionStats}];
    
    if (self.currentSessionStats.numRemaining > 0) {
        [self showStatusBarNotificationWithType:DFStatusUpdateProgress];
    } else if (self.currentSessionStats.numRemaining == 0 && self.currentSessionStats.numUploaded > 0) {
        [self showStatusBarNotificationWithType:DFStatusUpdateComplete];
    }
    
    DDLogInfo(@"%@", self.currentSessionStats.description);
}

- (void)showStatusBarNotificationWithType:(DFStatusUpdateType)updateType
{
    DFUploadSessionStats *sessionStats = self.currentSessionStats;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (updateType == DFStatusUpdateProgress) {
            NSString *statusString = [NSString stringWithFormat:@"Uploading. %lu left.", (unsigned long)self.currentSessionStats.numRemaining];
            
            [JDStatusBarNotification showWithStatus:statusString];
            [JDStatusBarNotification showProgress:sessionStats.progress];
        } else if (updateType == DFStatusUpdateComplete) {
            [JDStatusBarNotification showWithStatus:@"Upload complete." dismissAfter:2];
        } else if (updateType == DFStatusUpdateError) {
            [JDStatusBarNotification showWithStatus:@"Upload error.  Try again later." dismissAfter:5];
        } else if (updateType == DFStatusUpdateCancelled) {
            [JDStatusBarNotification showWithStatus:@"Upload cancelled." dismissAfter:2];
        } else if (updateType == DFStatusUpdateResumed) {
            [JDStatusBarNotification showWithStatus:@"Upload resuming..." dismissAfter:2];
        }
    });
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


# pragma mark - Background task helpes

- (void) beginBackgroundUpdateTask
{
    if (self.backgroundUpdateTask != UIBackgroundTaskInvalid) {
        DDLogVerbose(@"DFUploadController: have background upload task, no need to register another.");
        return;
    }
    self.backgroundUpdateTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        DDLogInfo(@"Background upload task about to expire.  Cancelling uploads...");
        
        // By cancel will throw an exception on the main thread because it could block.  That's the behavior
        // we want here so we create a semaphore an wait on it.
        dispatch_semaphore_t cancelSemaphore = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self cancelUploadsWithIsError:NO silent:YES];
            dispatch_semaphore_signal(cancelSemaphore);
        });
        dispatch_semaphore_wait(cancelSemaphore, DISPATCH_TIME_FOREVER);
        DDLogInfo(@"Uploads cancelled.  Ending background task.");
        
        [self endBackgroundUpdateTask];
    }];
}

- (void) endBackgroundUpdateTask
{
    [[UIApplication sharedApplication] endBackgroundTask: self.backgroundUpdateTask];
    self.backgroundUpdateTask = UIBackgroundTaskInvalid;
}


@end
