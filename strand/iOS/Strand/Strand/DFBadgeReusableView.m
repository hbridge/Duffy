//
//  DFBadgeReusableView.m
//  Strand
//
//  Created by Henry Bridge on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFBadgeReusableView.h"

@implementation DFBadgeReusableView

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self configureBadgeView];
}

- (void)configureBadgeView
{
  self.backgroundColor = [UIColor clearColor];
  self.badgeView = [[LKBadgeView alloc] initWithFrame:self.bounds];
  self.badgeView.badgeColor = [DFStrandConstants strandRed];
  self.badgeView.textColor = [UIColor whiteColor];
  self.badgeView.widthMode = LKBadgeViewWidthModeSmall;
  [self addSubview:self.badgeView];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configureBadgeView];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
    [self configureBadgeView];
  return self;
}

@end
