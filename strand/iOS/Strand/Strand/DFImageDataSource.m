//
//  DFImageDataSource.m
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageDataSource.h"
#import "DFImageStore.h"
#import "NSIndexPath+DFHelpers.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "UIDevice+DFHelpers.h"

@interface DFImageDataSource()

@property (nonatomic, retain) NSArray *localPhotoAssets;

@end

@implementation DFImageDataSource


- (instancetype)initWithFeedPhotos:(NSArray *)feedObjects
                        collectionView:(UICollectionView *)collectionView
                        sourceMode:(DFImageDataSourceMode)sourceMode
                         imageType:(DFImageType)imageType
{
  self = [super init];
  if (self) {
    NSMutableDictionary *indexPathsToObjects = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < feedObjects.count; i++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
      indexPathsToObjects[[indexPath dictKey]] = feedObjects[i];
    }
    _indexPathsToObjects = indexPathsToObjects;
    
    _collectionView = collectionView;
    [collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([DFPhotoViewCell class]) bundle:nil]
     forCellWithReuseIdentifier:@"cell"];
    _collectionView.dataSource = self;
    
    _imageType = imageType;
    _sourceMode = sourceMode;
    if (sourceMode == DFImageDataSourceModeLocal) {
      [self cacheLocalPhotoAssets:feedObjects];
    }
  }
  return self;
}

- (void)cacheLocalPhotoAssets:(NSArray *)feedObjects
{
  NSMutableArray *idsToFetch = [NSMutableArray new];
  for (DFPeanutFeedObject *feedObject in feedObjects) {
    if ([feedObject.type isEqualToString:DFFeedObjectCluster]) {
      DFPeanutFeedObject *photoObject = feedObject.objects.firstObject;
      [idsToFetch addObject:@(photoObject.id)];
    } else if ([feedObject.type isEqual:DFFeedObjectPhoto]) {
      [idsToFetch addObject:@(feedObject.id)];
    }
  }
  
  NSArray *photos = [[DFPhotoStore sharedStore] photosWithPhotoIDs:idsToFetch retainOrder:YES];
  NSMutableArray *photoAssets = [NSMutableArray new];
  for (DFPhoto *photo in photos) {
    [photoAssets addObject:photo.asset];
  }
  
  self.localPhotoAssets = photoAssets;
}



#pragma mark - Table View

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  if (self.sourceMode == DFImageDataSourceModeRemote)
    return self.indexPathsToObjects.keyEnumerator.allObjects.count;
  else if (self.sourceMode == DFImageDataSourceModeLocal)
    return self.localPhotoAssets.count;
  
  return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  
  DFPeanutFeedObject *feedObject = self.indexPathsToObjects[[indexPath dictKey]];
  DFPeanutFeedObject *photoObject;
  if ([feedObject.type isEqual:DFFeedObjectCluster]) {
    photoObject = feedObject.objects.firstObject;
  } else if ([feedObject.type isEqualToString:DFFeedObjectPhoto]) {
    photoObject = feedObject;
  } else {
    photoObject = nil;
  }
  
  if (_sourceMode == DFImageDataSourceModeRemote) {
    [[DFImageStore sharedStore]
     imageForID:photoObject.id
     preferredType:DFImageThumbnail
     thumbnailPath:photoObject.thumb_image_path
     fullPath:photoObject.full_image_path
     completion:^(UIImage *image) {
       dispatch_async(dispatch_get_main_queue(), ^{
         cell.imageView.image = image;
         [cell setNeedsLayout];
       });
     }];
  } else if (_sourceMode == DFImageDataSourceModeLocal){
    [self setLocalPhotosForCell:cell photoObject:photoObject indexPath:indexPath];
  }
  
  return cell;
}

- (void)setLocalPhotosForCell:(DFPhotoViewCell *)cell
                  photoObject:(DFPeanutFeedObject *)photoObject
                    indexPath:(NSIndexPath *)indexPath
{
  DFPhotoAsset *asset = self.localPhotoAssets[indexPath.row];
  
  CGFloat thumbnailSize;
  if ([UIDevice majorVersionNumber] >= 8 || self.imageType == DFImageFull) {
    // only use the larger thumbnails on iOS 8+, the scaling will kill perf on iOS7
    UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView.collectionViewLayout
                                                          layoutAttributesForItemAtIndexPath:indexPath];
    thumbnailSize = layoutAttributes.size.height * [[UIScreen mainScreen] scale];
  } else {
    thumbnailSize = DFPhotoAssetDefaultThumbnailSize;
  }
  [asset
   loadUIImageForThumbnailOfSize:thumbnailSize
   successBlock:^(UIImage *image) {
     cell.imageView.image = image;
   } failureBlock:^(NSError *error) {
     DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
   }];
}





@end
