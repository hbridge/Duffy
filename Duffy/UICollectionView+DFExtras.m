//
//  UICollectionView+DFExtras.m
//  Duffy
//
//  Created by Henry Bridge on 6/6/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "UICollectionView+DFExtras.h"

@implementation UICollectionView (DFExtras)

- (NSIndexPath *)indexPathForLastCell
{
  NSInteger sectionIndex = self.numberOfSections - 1;
  NSInteger itemIndex = [self numberOfItemsInSection:sectionIndex] - 1;
  NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex];
  return lastIndexPath;
}

@end
