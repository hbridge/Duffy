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

@property (nonatomic, retain) NSArray *sectionArrays;
@property (nonatomic, retain) NSMutableDictionary *localPhotoAssetsBySection;

@end

@implementation DFImageDataSource


- (instancetype)initWithFeedPhotos:(NSArray *)feedObjects
                        collectionView:(UICollectionView *)collectionView
                        sourceMode:(DFImageDataSourceMode)sourceMode
                         imageType:(DFImageType)imageType
{
  DFPeanutFeedObject *dummyObject = [[DFPeanutFeedObject alloc] init];
  dummyObject.objects = feedObjects;
  return [self initWithCollectionFeedObjects:@[dummyObject]
                              collectionView:collectionView
                                  sourceMode:sourceMode
                                   imageType:imageType];
}

- (void)setFeedPhotos:(NSArray *)feedPhotos
{
  DFPeanutFeedObject *dummyObject = [[DFPeanutFeedObject alloc] init];
  dummyObject.objects = feedPhotos;
  [self setCollectionFeedObjects:@[dummyObject]];
}

- (void)setCollectionFeedObjects:(NSArray *)collectionFeedObjects
{
  dispatch_async(dispatch_get_main_queue(), ^{
    _collectionFeedObjects = collectionFeedObjects;
    self.localPhotoAssetsBySection = [NSMutableDictionary new];
    NSMutableArray *sectionArrays = [NSMutableArray new];
    for (DFPeanutFeedObject *feedObject in collectionFeedObjects) {
      [sectionArrays addObject:feedObject.objects];
    }
    _sectionArrays = sectionArrays;
    [self.collectionView reloadData];
  });
}

- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                               collectionView:(UICollectionView *)collectionView
                                   sourceMode:(DFImageDataSourceMode)sourceMode
                                    imageType:(DFImageType)imageType
{
  self = [super init];
  if (self) {
    NSMutableArray *sectionArrays = [NSMutableArray new];
    for (DFPeanutFeedObject *feedObject in collectionFeedObjects) {
      [sectionArrays addObject:feedObject.objects];
    }
    _collectionFeedObjects = collectionFeedObjects;
    _sectionArrays = sectionArrays;
    _collectionView = collectionView;
    [collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([DFPhotoViewCell class]) bundle:nil]
     forCellWithReuseIdentifier:@"cell"];
    _collectionView.dataSource = self;
    
    _imageType = imageType;
    _sourceMode = sourceMode;
    if (sourceMode == DFImageDataSourceModeLocal) {
      [self cacheLocalPhotoAssetsForSection:sectionArrays.count - 1];
    }
  }
  return self;
}

- (void)cacheLocalPhotoAssetsForSection:(NSInteger)section
{
  if (section < 0 || section > self.sectionArrays.count - 1) return;
  if (!self.localPhotoAssetsBySection) self.localPhotoAssetsBySection = [NSMutableDictionary new];
  NSMutableArray *idsToFetch = [NSMutableArray new];
  for (DFPeanutFeedObject *feedObject in self.sectionArrays[section]) {
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
  
  self.localPhotoAssetsBySection[@(section)] = photoAssets;
}



#pragma mark - Table View

- (NSArray *)feedObjectsForSection:(NSUInteger)section
{
  return self.sectionArrays[section];
}

- (DFPeanutFeedObject *)feedObjectForIndexPath:(NSIndexPath *)indexPath
{
  NSArray *objects = self.sectionArrays[indexPath.section];
  DFPeanutFeedObject *feedObject = objects[indexPath.row];
  return feedObject;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return self.sectionArrays.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  NSArray *objects = self.sectionArrays[section];
  return objects.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  
  DFPeanutFeedObject *feedObject = [self feedObjectForIndexPath:indexPath];
    DFPeanutFeedObject *photoObject;
  if ([feedObject.type isEqual:DFFeedObjectCluster]) {
    photoObject = feedObject.objects.firstObject;
  } else if ([feedObject.type isEqualToString:DFFeedObjectPhoto]) {
    photoObject = feedObject;
  } else {
    photoObject = nil;
  }
  
  if (_sourceMode == DFImageDataSourceModeRemote) {
    [self setRemotePhotoForCell:cell photoObject:photoObject indexPath:indexPath];
  } else if (_sourceMode == DFImageDataSourceModeLocal){
    [self setLocalPhotosForCell:cell photoObject:photoObject indexPath:indexPath];
  }
  
  return cell;
}

- (void)setRemotePhotoForCell:(DFPhotoViewCell *)cell
                  photoObject:(DFPeanutFeedObject *)photoObject
                    indexPath:(NSIndexPath *)indexPath
{
  [[DFImageStore sharedStore]
   imageForID:photoObject.id
   preferredType:DFImageThumbnail
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       cell.imageView.image = image;
       [cell setNeedsLayout];
     });
   }];

}

- (void)setLocalPhotosForCell:(DFPhotoViewCell *)cell
                  photoObject:(DFPeanutFeedObject *)photoObject
                    indexPath:(NSIndexPath *)indexPath
{
  if (![self.localPhotoAssetsBySection.allKeys containsObject:@(indexPath.section)]) {
    [self cacheLocalPhotoAssetsForSection:indexPath.section];
  }
  NSArray *photoAssets = self.localPhotoAssetsBySection[@(indexPath.section)];
  DFPhotoAsset *asset = photoAssets[indexPath.row];
  
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
     dispatch_async(dispatch_get_main_queue(), ^{
       if ([[self.collectionView indexPathForCell:cell] isEqual:indexPath])
         cell.imageView.image = image;
     });
   } failureBlock:^(NSError *error) {
     DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
   }];
}

#pragma mark - Supplementary views forwarded

/* forward requests for header views to the delegate */
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  return [self.supplementaryViewDelegate collectionView:collectionView
                      viewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
}



@end
