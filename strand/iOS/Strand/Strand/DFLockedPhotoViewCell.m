//
//  DFLockedPhotoViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLockedPhotoViewCell.h"

@implementation DFLockedPhotoViewCell

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
  [super awakeFromNib];
  [self configureView];
}

- (void)configureView
{
  self.glassView = [[LFGlassView alloc] initWithFrame:self.imageView.frame];
  self.glassView.liveBlurring = NO;
  self.glassView.blurRadius = 1.0;
  [self.contentView addSubview:self.glassView];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self.glassView blurOnceIfPossible];
}

@end
