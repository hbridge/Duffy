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
#import "DFPeanutNotificationsManager.h"
#import "DFPeanutAction.h"

@interface DFImageDataSource()

@end

@implementation DFImageDataSource


- (instancetype)initWithFeedPhotos:(NSArray *)feedObjects
                        collectionView:(UICollectionView *)collectionView
{
  DFSection *section = [DFSection sectionWithTitle:nil object:nil rows:feedObjects];
  return [self initWithSections:@[section] collectionView:collectionView];
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
    NSMutableArray *sections = [[NSMutableArray alloc] initWithCapacity:collectionFeedObjects.count];
    for (DFPeanutFeedObject *feedObject in collectionFeedObjects) {
      DFSection *section = [DFSection sectionWithTitle:feedObject.title
                                                object:feedObject
                                                  rows:feedObject.objects];
      [sections addObject:section];
    }
    weakSelf.sections = sections;
  });
}

- (void)setSections:(NSArray *)sections
{
  DFImageDataSource __weak *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    NSUInteger previousCount = [_sections count];
    _sections = sections;
    [weakSelf.collectionView reloadData];
    
    if (previousCount == 0 && _sections.count > 0) {
      // this is the first data we've gotten, cache the bottom and send messages to delegate
      [self cacheImagesAroundSection:sections.count - 1];
      if ([self.imageDataSourceDelegate respondsToSelector:@selector(didFinishFirstLoadForDatasource:)]) {
        [self.imageDataSourceDelegate didFinishFirstLoadForDatasource:self];
      }
    }
  });

}

- (instancetype)initWithSections:(NSArray *)sections
                  collectionView:(UICollectionView *)collectionView
{
  self = [super init];
  if (self) {
    _collectionView = collectionView;
    [collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([DFPhotoViewCell class]) bundle:nil]
     forCellWithReuseIdentifier:@"cell"];
    _collectionView.dataSource = self;
    self.sections = sections;
  }
  return self;
}

- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                               collectionView:(UICollectionView *)collectionView
{
  NSArray *sections = [collectionFeedObjects arrayByMappingObjectsWithBlock:^id(DFPeanutFeedObject *collection) {
    return [DFSection sectionWithTitle:collection.title object:collection rows:collection.objects];
    
  }];
  return [self initWithSections:sections collectionView:collectionView];
}

NSUInteger const SectionSpread = 5;
- (void)cacheImagesAroundSection:(NSInteger)targetSection
{
  NSMutableArray *idsToFetch = [NSMutableArray new];
  for (NSInteger section = targetSection - SectionSpread; section <= targetSection + SectionSpread; section++) {
    if (section < 0 || section > self.sections.count - 1) continue;
    for (DFPeanutFeedObject *feedObject in [self.sections[section] rows]) {
      if ([feedObject.type isEqualToString:DFFeedObjectCluster]) {
        DFPeanutFeedObject *photoObject = feedObject.objects.firstObject;
        [idsToFetch addObject:@(photoObject.id)];
      } else if ([feedObject.type isEqual:DFFeedObjectPhoto]) {
        [idsToFetch addObject:@(feedObject.id)];
      }
    }
  }
  
  [[DFImageManager sharedManager]
   startCachingImagesForPhotoIDs:idsToFetch
   targetSize:[self cellPhotoSizeForIndexPath:[NSIndexPath indexPathForItem:0 inSection:targetSection]]
   contentMode:DFImageRequestContentModeAspectFill];
}



#pragma mark - Table View

- (NSArray *)feedObjectsForSection:(NSUInteger)section
{
  return [self.sections[section] rows];
}

- (NSArray *)photosForSection:(NSUInteger)section
{
  NSMutableArray *photoObjectsForSection = [NSMutableArray new];
  NSArray *objectsForSection = [self feedObjectsForSection:section];
  for (DFPeanutFeedObject *feedObject in objectsForSection) {
    [photoObjectsForSection addObjectsFromArray:[feedObject leafNodesFromObjectOfType:DFFeedObjectPhoto]];
  }
  return photoObjectsForSection;
}

- (DFPeanutFeedObject *)feedObjectForIndexPath:(NSIndexPath *)indexPath
{
  NSArray *objects = [self feedObjectsForSection:indexPath.section];
  if (indexPath.row >= objects.count) return nil;
  DFPeanutFeedObject *feedObject = objects[indexPath.row];
  return feedObject;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return self.sections.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  NSArray *objects = [self feedObjectsForSection:section];
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
  
  
  //NSArray *likes = [photoObject actionsOfType:DFPeanutActionFavorite forUser:0];
  NSArray *comments = [photoObject actionsOfType:DFPeanutActionComment forUser:0];
  NSUInteger numUnreadLikes = 0;
  // only count likes as unread if the photo is the current user's
  if (photoObject.user == [[DFUser currentUser] userID])
    numUnreadLikes = [[photoObject unreadActionsOfType:DFPeanutActionFavorite] count];
  
  if (self.showActionsBadge) {
    [cell setNumLikes:0 numComments:comments.count
       numUnreadLikes:0 numUnreadComments:0
     showUnreadDot:!(photoObject.evaluated.boolValue)];
    cell.badgeView.hidden = NO;
  } else {
    cell.countBadgeView.hidden = YES;
  }
  
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
   deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic
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
  return [self.imageDataSourceDelegate collectionView:collectionView
                      viewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
}



@end
