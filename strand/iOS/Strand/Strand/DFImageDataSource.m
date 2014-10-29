//
//  DFImageDataSource.m
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFImageDataSource.h"
#import "DFImageManager.h"
#import "NSIndexPath+DFHelpers.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStore.h"
#import "UIDevice+DFHelpers.h"

@interface DFImageDataSource()

@property (nonatomic, retain) NSArray *sectionArrays;

@end

@implementation DFImageDataSource


- (instancetype)initWithFeedPhotos:(NSArray *)feedObjects
                        collectionView:(UICollectionView *)collectionView
{
  DFPeanutFeedObject *dummyObject = [[DFPeanutFeedObject alloc] init];
  dummyObject.objects = feedObjects;
  return [self initWithCollectionFeedObjects:@[dummyObject]
                              collectionView:collectionView
          ];
}

- (void)setFeedPhotos:(NSArray *)feedPhotos
{
  DFPeanutFeedObject *dummyObject = [[DFPeanutFeedObject alloc] init];
  dummyObject.objects = feedPhotos;
  [self setCollectionFeedObjects:@[dummyObject]];
}

- (void)setCollectionFeedObjects:(NSArray *)collectionFeedObjects
{
  DFImageDataSource __weak *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSUInteger previousCount = [_collectionFeedObjects count];
    _collectionFeedObjects = collectionFeedObjects;
    NSMutableArray *sectionArrays = [NSMutableArray new];
    for (DFPeanutFeedObject *feedObject in collectionFeedObjects) {
      [sectionArrays addObject:feedObject.objects];
    }
    _sectionArrays = sectionArrays;
    [weakSelf.collectionView reloadData];
    
    if (previousCount == 0 && _collectionFeedObjects.count > 0) {
      // this is the first data we've gotten, cache the bottom and send messages to delegate
      [self cacheImagesAroundSection:sectionArrays.count - 1];
      if ([self.supplementaryViewDelegate respondsToSelector:@selector(didFinishFirstLoadForDatasource:)]) {
        [self.supplementaryViewDelegate didFinishFirstLoadForDatasource:self];
      }
    }
  });
}

- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                               collectionView:(UICollectionView *)collectionView
{
  self = [super init];
  if (self) {
    NSMutableArray *sectionArrays = [NSMutableArray new];
    for (DFPeanutFeedObject *feedObject in collectionFeedObjects) {
      [sectionArrays addObject:feedObject.objects];
    }
    _collectionFeedObjects = [collectionFeedObjects copy];
    _sectionArrays = sectionArrays;
    _collectionView = collectionView;
    [collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([DFPhotoViewCell class]) bundle:nil]
     forCellWithReuseIdentifier:@"cell"];
    _collectionView.dataSource = self;
  }
  return self;
}

- (void)cacheImagesAroundSection:(NSInteger)targetSection
{
  for (NSInteger section = targetSection-1; section <= targetSection +1; section++) {
    if (section < 0 || section > self.sectionArrays.count - 1) continue;
    
    NSMutableArray *idsToFetch = [NSMutableArray new];
    for (DFPeanutFeedObject *feedObject in self.sectionArrays[section]) {
      if ([feedObject.type isEqualToString:DFFeedObjectCluster]) {
        DFPeanutFeedObject *photoObject = feedObject.objects.firstObject;
        [idsToFetch addObject:@(photoObject.id)];
      } else if ([feedObject.type isEqual:DFFeedObjectPhoto]) {
        [idsToFetch addObject:@(feedObject.id)];
      }
    }
    
    [[DFImageManager sharedManager]
     startCachingImagesForPhotoIDs:idsToFetch
     targetSize:[self cellPhotoSizeForIndexPath:[NSIndexPath indexPathForItem:0 inSection:section]]
     contentMode:DFImageRequestContentModeAspectFill];
  }
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
  
  [self setImageForCell:cell photoObject:photoObject indexPath:indexPath];
  return cell;
}

- (void)setImageForCell:(DFPhotoViewCell *)cell
                  photoObject:(DFPeanutFeedObject *)photoObject
                    indexPath:(NSIndexPath *)indexPath
{
  UICollectionView *collectionView = self.collectionView;
  [[DFImageManager sharedManager]
   imageForID:photoObject.id
   size:[self cellPhotoSizeForIndexPath:indexPath]
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:DFImageRequestOptionsDeliveryModeFastFormat
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if ([[collectionView indexPathForCell:cell] isEqual:indexPath]) {
         // make sure we're setting the right image for the cell
         cell.imageView.image = image;
         [cell setNeedsLayout];
       }
     });
   }];
  
  if (indexPath.row == 0 ||
      indexPath.row == ([self.collectionView numberOfItemsInSection:indexPath.section] - 1)) {
    //if this is the first or last item in the section, cache around it
    [self cacheImagesAroundSection:indexPath.section];
  }
}

- (CGSize)cellPhotoSizeForIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView.collectionViewLayout
                                                        layoutAttributesForItemAtIndexPath:indexPath];
  CGFloat thumbnailSize;
  if ([UIDevice majorVersionNumber] >= 8 || thumbnailSize > DFPhotoAssetDefaultThumbnailSize * 2) {
    // only use the larger thumbnails on iOS 8+, the scaling will kill perf on iOS7
    thumbnailSize = layoutAttributes.size.height * [[UIScreen mainScreen] scale];
  } else {
    thumbnailSize = DFPhotoAssetDefaultThumbnailSize;
  }
  return CGSizeMake(thumbnailSize, thumbnailSize);
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
