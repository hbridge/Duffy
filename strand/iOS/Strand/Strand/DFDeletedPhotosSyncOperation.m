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
      [self.photoAdapter markPhotosAsNotOnSystem:photoIdsToRemove success:^(NSArray *resultObjects){
        for (DFPeanutPhoto *photo in resultObjects) {
          DDLogInfo(@"Successfully marked photo %@ as not in the system", photo.id);
        }
        // Lastly, we want to refresh our private data.
        [[DFPeanutFeedDataManager sharedManager] refreshPrivatePhotosFromServer:^{
          DDLogVerbose(@"Refreshed private photos data after successful delete");
        }];
      } failure:^(NSError *error){
        DDLogError(@"Unable to mark photos as not in the system: %@", error.description);
      }];
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
