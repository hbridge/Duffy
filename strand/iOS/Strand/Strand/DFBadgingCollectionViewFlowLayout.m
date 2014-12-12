//
//  DFBadgingCollectionViewFlowLayout.m
//  Strand
//
//  Created by Henry Bridge on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFBadgingCollectionViewFlowLayout.h"
#import <LKbadgeView/LKBadgeView.h>

NSString *const DFBadgingCollectionViewFlowLayoutBadgeView = @"DFBadgingCollectionViewFlowLayoutBadgeView";

@implementation DFBadgingCollectionViewFlowLayout

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
  //first get a copy of all layout attributes that represent the cells. you will be modifying this collection.
  NSMutableArray *allAttributes = [[super layoutAttributesForElementsInRect:rect] mutableCopy];
  
  //go through each cell attribute
  for (UICollectionViewLayoutAttributes *attributes in [super layoutAttributesForElementsInRect:rect])
  {
    DDLogVerbose(@"attr indexPath: [%@, %@]", @(attributes.indexPath.section), @(attributes.indexPath.row));
    //add a title and a detail supp view for each cell attribute to your copy of all attributes
    [allAttributes addObject:[self
                              layoutAttributesForSupplementaryViewOfKind:DFBadgingCollectionViewFlowLayoutBadgeView
                              atIndexPath:[attributes indexPath]]];
  }
  
  //return the updated attributes list along with the layout info for the supp views
  return allAttributes;
}

-(UICollectionViewLayoutAttributes*) layoutAttributesForSupplementaryViewOfKind:(NSString *)kind
                                                                    atIndexPath:(NSIndexPath *)indexPath{
  //create a new layout attributes to represent this reusable view
  UICollectionViewLayoutAttributes *attrs = [UICollectionViewLayoutAttributes
                                             layoutAttributesForSupplementaryViewOfKind:kind
                                             withIndexPath:indexPath];
  
  CGRect cellFrame = CGRectMake(indexPath.row % 3 * self.itemSize.width + self.minimumInteritemSpacing,
                                indexPath.row / 3 * self.itemSize.height + self.minimumLineSpacing + self.headerReferenceSize.height,
                                self.itemSize.width,
                                self.itemSize.height);
  if(attrs){
    if(kind == DFBadgingCollectionViewFlowLayoutBadgeView){
      //position this reusable view relative to the cells frame
      CGRect frame = cellFrame;
      frame.origin.x = CGRectGetMaxX(frame) - LK_BADGE_VIEw_MINIMUM_WIDTH - 1;
      frame.origin.y = frame.origin.y + 1;
      frame.size.width = LK_BADGE_VIEw_MINIMUM_WIDTH;
      frame.size.height = LK_BADGE_VIEW_STANDARD_HEIGHT;
      attrs.frame = frame;
    }
  }
  
  return attrs;
}

@end
