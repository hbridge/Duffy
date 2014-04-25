//
//  DFUploadOperation.m
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadOperation.h"
#import "DFPhotoUploadAdapter.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"

@interface DFUploadOperation()

@property (nonatomic, readonly, retain) NSManagedObjectContext *managedObjectContext;

@end

@implementation DFUploadOperation

@synthesize photoID, completionOperationQueue, successBlock, failureBlock;
@synthesize managedObjectContext = _managedObjectContext;


- (id)initWithPhotoID:(NSManagedObjectID *)newPhotoID
{
    self = [super init];
    if (self) {
        self.photoID = newPhotoID;
    }
    return self;
}

- (void)main
{
    @autoreleasepool {
        // get the photo
        DFPhoto *photo = (DFPhoto *)[self.managedObjectContext objectWithID:self.photoID];
        if (!photo || !([[photo class] isSubclassOfClass:[DFPhoto class]])) {
            [self failure:[NSError errorWithDomain:@"com.duffyapp.Duffy.DFUploadOperation" code:-100 userInfo:@{NSLocalizedDescriptionKey: @"objectWithID was invalid"}]];
        }
        
        DFPhotoUploadAdapter *uploadAdapter = [[DFPhotoUploadAdapter alloc] init];
        NSDictionary *result = [uploadAdapter uploadPhoto:photo];
        
        if (result[DFUploadResultNumBytes]) {
            [self success:[result[DFUploadResultNumBytes] unsignedIntegerValue]];
        } else {
            [self failure:result[DFUploadResultErrorKey]];
        }
    }
}

- (void)failure:(NSError *)error
{
    NSOperationQueue __block *completionQueue = self.completionOperationQueue;
    DFPhotoUploadOperationFailureBlock __block cachedFailureBlock = self.failureBlock;
    
    [self setCompletionBlock:^{
        [completionQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            cachedFailureBlock(error);
        }]];
    }];
}

- (void)success:(NSUInteger)numBytes
{
    NSOperationQueue __block *completionQueue = self.completionOperationQueue;
    DFPhotoUploadOperationSuccessBlock __block cachedSuccessBlock = self.successBlock;
    [self setCompletionBlock:^{
        [completionQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            cachedSuccessBlock(numBytes);
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
