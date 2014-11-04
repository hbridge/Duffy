//
//  DFDeletedPhotosSyncOperation.m
//  Strand
//
//  Created by Derek Parham on 10/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDeletedPhotosSyncOperation.h"

#import "DFPeanutPhotoAdapter.h"

#import "DFImageManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFPeanutPhoto.h"

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
    
    DFImageManager *imageManager = [DFImageManager sharedManager];
    // Grab list of private images the server has handed us
    NSArray *privatePhotos = [[DFPeanutFeedDataManager sharedManager] privatePhotos];
    NSMutableArray *photoIdsToRemove = [NSMutableArray new];
    
    DDLogInfo(@"For delete sync, evaling %lu photos", (unsigned long)privatePhotos.count);
    // For each image, see if we can get bytes for it from the ImageManager
    for (DFPeanutFeedObject *photo in privatePhotos) {
      [imageManager imageForID:photo.id preferredType:DFImageThumbnail completion:^(UIImage *image) {
        if (!image) {
          DDLogInfo(@"For delete sync, did not find photo data for photo id %llu", photo.id);
          
          [photoIdsToRemove addObject:@(photo.id)];
        }
      }];
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
        [[NSNotificationCenter defaultCenter]
         postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
         object:self];
      } failure:^(NSError *error){
        DDLogError(@"Unable to mark photos as not in the system: %@", error.description);
      }];
    }
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
