//
//  DFDeletedPhotosSyncOperation.m
//  Strand
//
//  Created by Derek Parham on 10/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDeletedPhotosSyncOperation.h"

#import "DFPeanutPhotoAdapter.h"

#import "DFPeanutFeedDataManager.h"
#import "DFPeanutPhoto.h"
#import "DFPhotoStore.h"
#import "DFUploadController.h"

@interface DFDeletedPhotosSyncOperation ()
@property (readonly, nonatomic, retain) DFPeanutPhotoAdapter *photoAdapter;

@end

@implementation DFDeletedPhotosSyncOperation

@synthesize photoAdapter = _photoAdapter;

- (void)main
{
  @autoreleasepool {
    DDLogInfo(@"%@ main beginning.", self.class);
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    
    // If we're currently uploading stuff, then don't go deleting anything.
    if ([[DFUploadController sharedUploadController] isUploadInProgress]) {
      DDLogInfo(@"Leaving delete sync because upload is in progress");
      return;
    }
    
    NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
    
    // Grab list of private images the server has handed us
    NSArray *privatePhotos = [[DFPeanutFeedDataManager sharedManager] privatePhotos];
    NSMutableArray *photoIds = [NSMutableArray new];
    NSMutableArray *photoIdsToRemove = [NSMutableArray new];
    
    DDLogInfo(@"For delete sync, evaling %lu photos", (unsigned long)privatePhotos.count);
    // For each image, see if we can get bytes for it from the ImageManager
    for (DFPeanutFeedObject *photo in privatePhotos) {
      [photoIds addObject:@(photo.id)];
    }
    
    NSDictionary *photosThatExist = [DFPhotoStore photosWithPhotoIDs:photoIds inContext:context];
    
    for (NSNumber *photoId in photoIds) {
      if (![photosThatExist objectForKey:photoId]) {
        [photoIdsToRemove addObject:photoId];
      }
    }
    
    if (self.isCancelled) {
      [self cancelled];
      return;
    }
    if (photoIdsToRemove.count > 0) {
      dispatch_semaphore_t completionSemaphore = dispatch_semaphore_create(0);
      [[DFPeanutFeedDataManager sharedManager] markPhotosAsNotOnSystem:photoIdsToRemove success:^(){
        dispatch_semaphore_signal(completionSemaphore);
      } failure:^(NSError *error){
        dispatch_semaphore_signal(completionSemaphore);
      }];
      dispatch_semaphore_wait(completionSemaphore,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)));
    }
    
    DDLogInfo(@"Delete sync completed");
  }
}

- (void)cancelled
{
  DDLogInfo(@"%@ cancelled.  Stopping.", self.class);
}



#pragma mark - Adapters

- (DFPeanutPhotoAdapter *)photoAdapter
{
  if (!_photoAdapter) {
    _photoAdapter = [[DFPeanutPhotoAdapter alloc] init];
  }
  
  return _photoAdapter;
}

@end
