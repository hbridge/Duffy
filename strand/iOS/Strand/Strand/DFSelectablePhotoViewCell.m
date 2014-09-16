//
//  DFSelectablePhotoViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectablePhotoViewCell.h"

@implementation DFSelectablePhotoViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.contentView.translatesAutoresizingMaskIntoConstraints = YES;
}

- (void)setShowTickMark:(BOOL)showTickMark
{
  self.selectedImageView.hidden = !showTickMark;
  [self setNeedsLayout];
}

- (BOOL)showTickMark
{
  return !self.selectedImageView.hidden;
}

@end
