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
  if (sectionIndex > 0 && itemIndex > 0)
    return [NSIndexPath indexPathForItem:itemIndex inSection:sectionIndex];
  return nil;
}

- (void)scrollToBottom
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *ip = [self indexPathForLastCell];
    if (ip) {
      [self scrollToItemAtIndexPath:ip
                   atScrollPosition:UICollectionViewScrollPositionTop
                           animated:NO];
    }
  });
}

@end
