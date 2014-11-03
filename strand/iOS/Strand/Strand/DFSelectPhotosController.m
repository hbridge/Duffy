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
{
  self = [super initWithFeedPhotos:feedObjects collectionView:collectionView];
  if (self) {
    _selectedFeedObjects = [feedObjects mutableCopy];
    [self.collectionView registerNib:[UINib nibForClass:[DFSelectablePhotoViewCell class]]
          forCellWithReuseIdentifier:@"selectableCell"];
  }
  return self;
}

- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                               collectionView:(UICollectionView *)collectionView
{
  self = [super initWithCollectionFeedObjects:collectionFeedObjects
                               collectionView:collectionView];
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

- (void)toggleObjectSelected:(DFPeanutFeedObject *)object
{
  if ([self.selectedFeedObjects containsObject:object]) {
    [self.selectedFeedObjects removeObject:object];
  } else {
    [self.selectedFeedObjects addObject:object];
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
  NSArray *photos = [feedObject leafNodesFromObjectOfType:DFFeedObjectPhoto];
  photoObject = [photos firstObject];
  cell.count = (photos.count > 1) ? photos.count : 0;
  
  [self setImageForCell:cell photoObject:photoObject indexPath:indexPath];
  NSSet *selectedSet = [NSSet setWithArray:self.selectedFeedObjects];
  cell.showTickMark = [selectedSet intersectsSet:[NSSet setWithArray:photos]];
  
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

#pragma mark - DFSelectablePhotoViewCell Delegate

- (void)cell:(DFSelectablePhotoViewCell *)cell selectPhotoButtonPressed:(UIButton *)selectPhotoButton
{
  NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
  DFPeanutFeedObject *object = [self feedObjectForIndexPath:indexPath];
  NSArray *objectsToSelect = [object leafNodesFromObjectOfType:DFFeedObjectPhoto];
  
  if (selectPhotoButton.selected) {
    [self.selectedFeedObjects removeObjectsInArray:objectsToSelect];
    selectPhotoButton.selected = NO;
  } else {
    [self.selectedFeedObjects addObjectsFromArray:objectsToSelect];
    selectPhotoButton.selected = YES;
  }
  
  [self.delegate selectPhotosController:self selectedFeedObjectsChanged:self.selectedFeedObjects];
}

- (void)cellLongpressed:(DFSelectablePhotoViewCell *)cell
{
  NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
  DFPeanutFeedObject *object = [self feedObjectForIndexPath:indexPath];
  
  if ([self.delegate respondsToSelector:@selector(selectPhotosController:feedObjectLongpressed:inSection:)])
    [self.delegate selectPhotosController:self feedObjectLongpressed:object inSection:indexPath.section];
}


@end
