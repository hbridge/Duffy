//
//  DFUploadOperation.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadOperation.h"
#import "DFPhotoImageDataAdapter.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"
#import "DFPhotoMetadataAdapter.h"
#import <RestKit/RestKit.h>
#import "DFObjectManager.h"

@interface DFUploadOperation()

@property (nonatomic, readonly, retain) NSManagedObjectContext *managedObjectContext;

@end

@implementation DFUploadOperation

@synthesize photoIDs, completionOperationQueue, successBlock, failureBlock;
@synthesize managedObjectContext = _managedObjectContext;


- (id)initWithPhotoIDs:(NSArray *)IDs uploadOperationType:(DFPhotoUploadOperationImageDataType)imageUploadType;
{
    self = [super init];
    if (self) {
        self.photoIDs = IDs;
        self.uploadOperationType = imageUploadType;
    }
    return self;
}

- (void)main
{
    @autoreleasepool {
        // get the photo
        NSDate *startDate = [NSDate date];
        DDLogInfo(@"DFUploadOperation starting at %@", [startDate description]);
        NSMutableArray *photos = [[NSMutableArray alloc] initWithCapacity:self.photoIDs.count];
        
        for (NSManagedObjectID *photoID in self.photoIDs) {
            DFPhoto *photo = (DFPhoto *)[self.managedObjectContext objectWithID:photoID];
            if (!photo || !([[photo class] isSubclassOfClass:[DFPhoto class]])) {
                [self failureWithError:[NSError errorWithDomain:@"com.duffyapp.Duffy.DFUploadOperation"
                                                           code:-100
                                                       userInfo:@{NSLocalizedDescriptionKey: @"objectWithID was invalid"}]];
            }
            [photos addObject:photo];
        }
        if (self.isCancelled) return;

        DFPhotoMetadataAdapter *photoAdapter = [[DFPhotoMetadataAdapter alloc] initWithObjectManager:[DFObjectManager sharedManager]];
        NSDictionary *result;
        NSDate *postStartDate = [NSDate date];
        DDLogInfo(@"Post operation starting at %@ ", postStartDate.description);
        if (self.uploadOperationType == DFPhotoUploadOperation157Data) {
            result = [photoAdapter postPhotosWithThumbnails:photos];
        } else if (self.uploadOperationType == DFPhotoUploadOperation569Data) {
            result = [photoAdapter postPhotosWithFullImages:photos];
        }
        DDLogInfo(@"Post operation finished for %lu photos with elapsed time:%.02f", (unsigned long)photos.count, [[NSDate date] timeIntervalSinceDate:postStartDate]);
        
        
        if (self.isCancelled) [[[DFObjectManager sharedManager] operationQueue] cancelAllOperations];
        
        if (!result[DFUploadResultErrorKey]) {
            [self successForDFPeanutPhotos:(NSArray *)result[DFUploadResultPeanutPhotos]];
        } else {
            [self failureWithError:result[DFUploadResultErrorKey]];
        }
        
        DDLogInfo(@"DFUploadOperation finished for %lu photos with elapsed time:%.02f", (unsigned long)photos.count, [[NSDate date] timeIntervalSinceDate:startDate]);
    }
}

- (void)failureWithError:(NSError *)error
{
    NSOperationQueue __block *completionQueue = self.completionOperationQueue;
    DFPhotoUploadOperationFailureBlock __block cachedFailureBlock = self.failureBlock;
    BOOL __block cachedCancelled = self.isCancelled;
    NSArray __block *cachedPhotoIDs = self.photoIDs;
    DFPhotoUploadOperationImageDataType __block cachedUploadType = self.uploadOperationType;
    
    [self setCompletionBlock:^{
        [completionQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            cachedFailureBlock(error, cachedPhotoIDs, cachedUploadType,cachedCancelled);
        }]];
    }];
}

- (void)successForDFPeanutPhotos:(NSArray *)peanutPhotos
{
    NSOperationQueue __block *completionQueue = self.completionOperationQueue;
    DFPhotoUploadOperationSuccessBlock __block cachedSuccessBlock = self.successBlock;
    [self setCompletionBlock:^{
        [completionQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            cachedSuccessBlock(peanutPhotos);
        }]];
    }];
}

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


@end
