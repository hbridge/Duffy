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

- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                               collectionView:(UICollectionView *)collectionView
                                   sourceMode:(DFImageDataSourceMode)sourceMode
                                    imageType:(DFImageType)imageType
{
  self = [super initWithCollectionFeedObjects:collectionFeedObjects
                               collectionView:collectionView
                                   sourceMode:sourceMode
                                    imageType:imageType];
  _selectedFeedObjects = [NSMutableArray new];
  [self.collectionView registerNib:[UINib nibForClass:[DFSelectablePhotoViewCell class]]
        forCellWithReuseIdentifier:@"selectableCell"];
  
  return self;
}

- (void)toggleSectionSelection:(NSUInteger)section
{
  NSSet *selectedItemsFromSection = [self selectedItemsFromSection:section];
  BOOL select;
  if (selectedItemsFromSection.count > 0) {
    [self.selectedFeedObjects removeObjectsInArray:selectedItemsFromSection.allObjects];
    select = NO;
  } else {
    [self.selectedFeedObjects addObjectsFromArray:[self feedObjectsForSection:section]];
    select = YES;
  }

  for (DFSelectablePhotoViewCell *cell in self.collectionView.visibleCells) {
    if ([[self.collectionView indexPathForCell:cell] section] == section) {
      cell.showTickMark = select;
      [cell setNeedsLayout];
    }
  }
  [self.delegate selectPhotosController:self selectedFeedObjectsChanged:self.selectedFeedObjects];
}

- (NSSet *)selectedItemsFromSection:(NSUInteger)section
{
  NSMutableSet *sectionObjects = [NSMutableSet setWithArray:[self feedObjectsForSection:section]];
  NSSet *selectedObjects = [NSSet setWithArray:[self selectedFeedObjects]];
  [sectionObjects intersectSet:selectedObjects];
  return sectionObjects;
}

- (NSArray *)collectionFeedObjectsWithSelectedObjects
{
  NSMutableArray *feedObjects = [NSMutableArray new];
  for (NSUInteger i = 0; i < [self numberOfSectionsInCollectionView:self.collectionView]; i++) {
    if ([[self selectedItemsFromSection:i] count] > 0) {
      [feedObjects addObject:self.collectionFeedObjects[i]];
    }
  }
  return feedObjects;
}


#pragma mark - UICollectionView Data/Delegate

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFSelectablePhotoViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"selectableCell"
                                                                              forIndexPath:indexPath];
  cell.delegate = self;
  DFPeanutFeedObject *feedObject = [self feedObjectForIndexPath:indexPath];
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
  
  cell.showTickMark = [self.selectedFeedObjects containsObject:feedObject];
  
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
      if ([subObject.type isEqual:DFFeedObjectPhoto]) {
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
  DFPeanutFeedObject *object = [self feedObjectForIndexPath:indexPath];
  if (selectPhotoButton.selected) {
    [self.selectedFeedObjects removeObject:object];
    selectPhotoButton.selected = NO;
  } else {
    [self.selectedFeedObjects addObject:object];
    selectPhotoButton.selected = YES;
  }
  
  [self.delegate selectPhotosController:self selectedFeedObjectsChanged:self.selectedFeedObjects];
}




@end
