//
//  DFSelectPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectPhotosController.h"
#import "DFSelectablePhotoViewCell.h"
#import "UINib+DFHelpers.h"
#import "NSArray+DFHelpers.h"

@interface DFSelectPhotosController (DFImageDataSource)

@property (nonatomic, retain) NSArray *localPhotoAssets;


@end

@implementation DFSelectPhotosController

- (instancetype)initWithFeedPhotos:(NSArray *)feedObjects
                    collectionView:(UICollectionView *)collectionView
                        sourceMode:(DFImageDataSourceMode)sourceMode
                         imageType:(DFImageType)imageType
{
  self = [super initWithFeedPhotos:feedObjects collectionView:collectionView sourceMode:sourceMode imageType:imageType];
  if (self) {
    _selectedFeedObjects = [feedObjects mutableCopy];
    [self.collectionView registerNib:[UINib nibForClass:[DFSelectablePhotoViewCell class]]
          forCellWithReuseIdentifier:@"selectableCell"];
  }
  return self;
}


#pragma mark - UICollectionView Data/Delegate

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFSelectablePhotoViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"selectableCell"
                                                                              forIndexPath:indexPath];
  cell.delegate = self;
  DFPeanutFeedObject *feedObject = self.feedObjects[indexPath.row];
  DFPeanutFeedObject *photoObject;
  if ([feedObject.type isEqual:DFFeedObjectCluster]) {
    photoObject = feedObject.objects.firstObject;
    cell.count = feedObject.objects.count;
  } else if ([feedObject.type isEqualToString:DFFeedObjectPhoto]) {
    photoObject = feedObject;
    cell.count = 0;
  } else {
    photoObject = nil;
  }
  
  if (self.sourceMode == DFImageDataSourceModeRemote) {
    [self setRemotePhotoForCell:cell photoObject:photoObject indexPath:indexPath];
  } else if (self.sourceMode == DFImageDataSourceModeLocal){
    [self setLocalPhotosForCell:cell photoObject:photoObject indexPath:indexPath];
  }
  
  cell.showTickMark = [self.selectedFeedObjects containsObject:photoObject];
  
  return cell;
}

- (NSArray *)selectedPhotoIDs
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFPeanutFeedObject *object in self.selectedFeedObjects)
  {
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [result addObject:@(object.id)];
      continue;
    }
    for (DFPeanutFeedObject *subObject in object.enumeratorOfDescendents.allObjects) {
      if ([subObject isEqual:DFFeedObjectPhoto]) {
        [result addObject:@(subObject.id)];
      }
    }
  }
  return result;
}

const NSUInteger MaxSharedPhotosDisplayed = 3;


- (void)cell:(DFSelectablePhotoViewCell *)cell selectPhotoButtonPressed:(UIButton *)selectPhotoButton
{
  NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
  DFPeanutFeedObject *object = self.feedObjects[indexPath.row];
  if (selectPhotoButton.selected) {
    [self.selectedFeedObjects removeObject:object];
    selectPhotoButton.selected = NO;
  } else {
    [self.selectedFeedObjects addObject:object];
    selectPhotoButton.selected = YES;
  }
  
  if (self.delegate) {
    [self.delegate selectPhotosController:self selectedFeedObjectsChanged:self.selectedFeedObjects];
  }
}


//- (void)collectionView:(UICollectionView *)collectionView
//didSelectItemAtIndexPath:(NSIndexPath *)indexPath
//{
//  DFPeanutFeedObject *sectionObject = [self objectForSection:indexPath.section];
//  if  (sectionObject != self.suggestedSectionObject) return;
//  DFPeanutFeedObject *photoObject = [self photosForSection:indexPath.section][indexPath.row];
//  NSUInteger index = [self.selectedPhotoIDs indexOfObject:@(photoObject.id)];
//  if (index != NSNotFound) {
//    [self.selectedPhotoIDs removeObjectAtIndex:index];
//  } else {
//    [self.selectedPhotoIDs addObject:@(photoObject.id)];
//  }
//  
//  DDLogVerbose(@"selectedIndex:%@ photoID:%@ selectedPhotoIDs:%@",
//               indexPath.description,
//               @(photoObject.id),
//               self.selectedPhotoIDs);
//  
//  [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
//  [self.collectionView deselectItemAtIndexPath:indexPath animated:YES];
//}




@end
