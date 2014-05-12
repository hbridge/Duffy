//
//  DFUploadOperation.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadOperation.h"
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
        NSMutableArray *photos = [[NSMutableArray alloc] initWithCapacity:self.photoIDs.count];
        
        for (NSManagedObjectID *photoID in self.photoIDs) {
            DFPhoto *photo = (DFPhoto *)[self.managedObjectContext objectWithID:photoID];
            if (photo && [[photo class] isSubclassOfClass:[DFPhoto class]]) {
                [photos addObject:photo];
            } else {
                [self failureWithResultDict:@{DFUploadResultErrorKey : [NSError errorWithDomain:@"com.duffyapp.Duffy.DFUploadOperation"
                                                                                           code:-100
                                                                                       userInfo:@{NSLocalizedDescriptionKey: @"objectWithID was invalid"}]}];
            }
            
        }
        if (self.isCancelled) return;

        DFPhotoMetadataAdapter *photoAdapter = [[DFPhotoMetadataAdapter alloc] initWithObjectManager:[DFObjectManager sharedManager]];
        NSDictionary *result;
        if (self.uploadOperationType == DFPhotoUploadOperationThumbnailData) {
            result = [photoAdapter postPhotos:photos appendThumbnailData:YES];
        } else if (self.uploadOperationType == DFPhotoUploadOperationFullImageData) {
            if (photos.count > 1) [NSException raise:@"DFPhotoUploadOperation: not supported"
                                              format:@"Attempting to upload %lu photos in a full image data upload operation", photos.count];
            result = [photoAdapter putPhoto:[photos firstObject] updateMetadata:NO appendLargeImageData:YES];
        }

        if (self.isCancelled) [[[DFObjectManager sharedManager] operationQueue] cancelAllOperations];
        
        if (!result[DFUploadResultErrorKey]) {
            [self successForWithResultDict:result];
        } else {
            [self failureWithResultDict:result];
        }
    }
}

- (void)failureWithResultDict:(NSDictionary *)resultDict
{
    NSOperationQueue __block *completionQueue = self.completionOperationQueue;
    DFPhotoUploadOperationFailureBlock __block cachedFailureBlock = self.failureBlock;
    BOOL __block cachedCancelled = self.isCancelled;
    
    [self setCompletionBlock:^{
        [completionQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            cachedFailureBlock(resultDict, cachedCancelled);
        }]];
    }];
}

- (void)successForWithResultDict:(NSDictionary *)resultDict
{
    NSOperationQueue __block *completionQueue = self.completionOperationQueue;
    DFPhotoUploadOperationSuccessBlock __block cachedSuccessBlock = self.successBlock;
    
    [self setCompletionBlock:^{
        [completionQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            cachedSuccessBlock(resultDict);
        }]];
    }];
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
  
  _managedObjectContext = [[DFPhotoStore sharedStore] createBackgroundManagedObjectContext];
    return _managedObjectContext;
}


@end
