//
//  DFGalleryCollectionViewFlowLayout.m
//  Strand
//
//  Created by Henry Bridge on 9/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFGalleryCollectionViewFlowLayout.h"

@implementation DFGalleryCollectionViewFlowLayout

/* sticky headers from: 
 http://blog.radi.ws/post/32905838158/sticky-headers-for-uicollectionview-using 
 */

- (NSArray *) layoutAttributesForElementsInRect:(CGRect)rect {
  
  NSMutableArray *answer = [[super layoutAttributesForElementsInRect:rect] mutableCopy];
  UICollectionView * const cv = self.collectionView;
  CGPoint const contentOffset = cv.contentOffset;
  
  NSMutableIndexSet *missingSections = [NSMutableIndexSet indexSet];
  for (UICollectionViewLayoutAttributes *layoutAttributes in answer) {
    if (layoutAttributes.representedElementCategory == UICollectionElementCategoryCell) {
      [missingSections addIndex:layoutAttributes.indexPath.section];
    }
  }
  for (UICollectionViewLayoutAttributes *layoutAttributes in answer) {
    if ([layoutAttributes.representedElementKind isEqualToString:UICollectionElementKindSectionHeader]) {
      [missingSections removeIndex:layoutAttributes.indexPath.section];
    }
  }
  
  [missingSections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:idx];
    
    UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
    
    [answer addObject:layoutAttributes];
    
  }];
  
  for (UICollectionViewLayoutAttributes *layoutAttributes in answer) {
    
    if ([layoutAttributes.representedElementKind isEqualToString:UICollectionElementKindSectionHeader]) {
      
      NSInteger section = layoutAttributes.indexPath.section;
      NSInteger numberOfItemsInSection = [cv numberOfItemsInSection:section];
      
      NSIndexPath *firstCellIndexPath = [NSIndexPath indexPathForItem:0 inSection:section];
      NSIndexPath *lastCellIndexPath = [NSIndexPath indexPathForItem:MAX(0, (numberOfItemsInSection - 1)) inSection:section];
      
      UICollectionViewLayoutAttributes *firstCellAttrs = [self layoutAttributesForItemAtIndexPath:firstCellIndexPath];
      UICollectionViewLayoutAttributes *lastCellAttrs = [self layoutAttributesForItemAtIndexPath:lastCellIndexPath];
      
      CGFloat headerHeight = CGRectGetHeight(layoutAttributes.frame);
      CGPoint origin = layoutAttributes.frame.origin;
      origin.y = MIN(
                     MAX(
                         contentOffset.y,
                         (CGRectGetMinY(firstCellAttrs.frame) - headerHeight)
                         ),
                     (CGRectGetMaxY(lastCellAttrs.frame) - headerHeight)
                     );
      
      layoutAttributes.zIndex = 1024;
      layoutAttributes.frame = (CGRect){
        .origin = origin,
        .size = layoutAttributes.frame.size
      };
      
    }
    
  }
  
  return answer;
  
}

- (BOOL) shouldInvalidateLayoutForBoundsChange:(CGRect)newBound {
  
  return YES;
  
}

@end
