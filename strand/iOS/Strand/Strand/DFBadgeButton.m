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

- (void)configureView
{
  self.badgeView = [[LKBadgeView alloc] initWithFrame:CGRectMake(0, 5, 50, 20)];
  [self addSubview:self.badgeView];
  
  self.badgeView.badgeColor = self.badgeColor;
  self.badgeView.textColor = self.badgeTextColor;
  self.badgeView.horizontalAlignment = LKBadgeViewHorizontalAlignmentLeft;
  self.badgeView.widthMode = LKBadgeViewWidthModeSmall;
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

@end
