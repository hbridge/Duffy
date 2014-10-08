//
//  DFPhotoStackCell.m
//  Duffy
//
//  Created by Henry Bridge on 6/3/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStackCell.h"
#import "DFStrandConstants.h"

const CGFloat rightBadgeMargin = 8.0;
const CGFloat bottomBadgeMargin = 8.0;

@implementation DFPhotoStackCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.contentView.translatesAutoresizingMaskIntoConstraints = YES;
  self.badgeView.backgroundColor = [DFStrandConstants photoCellBadgeColor];
}

//- (CGRect)frameForBadgeView
//{
//  CGFloat badgeWidth = self.badgeView.widthMode == LKBadgeViewHeightModeStandard ?
//    LK_BADGE_VIEw_STANDARD_WIDTH + 10 : LK_BADGE_VIEw_MINIMUM_WIDTH;
//  return CGRectMake(self.frame.size.width - badgeWidth - rightBadgeMargin,
//                    self.frame.size.height - LK_BADGE_VIEW_STANDARD_HEIGHT - bottomBadgeMargin,
//                    badgeWidth,
//                    LK_BADGE_VIEW_STANDARD_HEIGHT);
//}

- (void)setCount:(NSUInteger)count
{
  _count = count;
  if (count > 9) {
    self.badgeView.text = @"9+";
    self.badgeView.hidden = NO;
  } else if (count > 0) {
    self.badgeView.text = [@(count) stringValue];
    self.badgeView.hidden = NO;
  } else {
    self.badgeView.hidden = YES;
  }
  
  [self setNeedsLayout];
}

@end
