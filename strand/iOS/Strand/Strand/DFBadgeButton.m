//
//  DFBadgeButton.m
//  Strand
//
//  Created by Henry Bridge on 7/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFBadgeButton.h"
#import "LKBadgeView.h"


@interface DFBadgeButton()

@property (nonatomic, retain)LKBadgeView *badgeView;

@end

@implementation DFBadgeButton

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self configureView];
  }
  return self;
}

- (void)awakeFromNib
{
  [self configureView];
}

- (CGRect)calculateBadgeFrame
{
  CGSize badgeSize = CGSizeMake(LK_BADGE_VIEw_STANDARD_WIDTH, LK_BADGE_VIEW_STANDARD_HEIGHT);
  CGRect frame = CGRectMake(self.bounds.size.width - badgeSize.width/3,
                            -badgeSize.height/4,
                            badgeSize.width,
                            badgeSize.height);
  frame.origin.x += self.badgeEdgeInsets.left - self.badgeEdgeInsets.right;
  frame.origin.y += self.badgeEdgeInsets.top - self.badgeEdgeInsets.bottom;
  return frame;
}

- (void)configureView
{
  self.badgeView = [[LKBadgeView alloc] initWithFrame:[self calculateBadgeFrame]];
  [self insertSubview:self.badgeView aboveSubview:self.titleLabel];
  
  self.badgeView.badgeColor = self.badgeColor;
  self.badgeView.textColor = self.badgeTextColor;
  self.badgeView.horizontalAlignment = LKBadgeViewHorizontalAlignmentLeft;
  self.badgeView.widthMode = LKBadgeViewWidthModeSmall;
  [self.badgeView sizeToFit];
}

- (void)setBadgeEdgeInsets:(UIEdgeInsets)badgeEdgeInsets
{
  _badgeEdgeInsets = badgeEdgeInsets;
  [self calculateBadgeFrame];
}

- (void)setBadgeColor:(UIColor *)badgeColor
{
  _badgeColor = badgeColor;
  self.badgeView.badgeColor = badgeColor;
}

- (void)setBadgeTextColor:(UIColor *)badgeTextColor
{
  _badgeTextColor = badgeTextColor;
  self.badgeView.textColor = badgeTextColor;
}

- (void)setBadgeCount:(int)badgeCount
{
  if (badgeCount > 0) {
    self.badgeView.hidden = NO;
    int countToDisplay = badgeCount < 100 ? badgeCount : 99;
    self.badgeView.text = [NSString stringWithFormat:@"%d", countToDisplay];
  } else {
    self.badgeView.hidden = YES;
  }
}

- (void)layoutSubviews
{
  self.badgeView.frame = [self calculateBadgeFrame];
  
  [super layoutSubviews];
}

//- (CGSize)sizeThatFits:(CGSize)size
//{
//  CGSize sizeThatFits = [super sizeThatFits:size];
//  if (self.badgeView.frame.origin.x + self.badgeView.frame.size.width > sizeThatFits.width) {
//    sizeThatFits.width = self.badgeView.frame.origin.x + self.badgeView.frame.size.width;
//  }
//  
//  return sizeThatFits;
//}


@end
