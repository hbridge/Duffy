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

- (void)setCount:(NSUInteger)count
{
  _count = count;
  if (count > 0) self.countView.text = [@(count) stringValue];
  self.countView.hidden = YES;
}

- (void)setShowTickMark:(BOOL)showTickMark
{
  self.selectPhotoButton.selected = showTickMark;
  [self setNeedsLayout];
}

- (BOOL)showTickMark
{
  return self.selectPhotoButton.selected;
}

- (IBAction)selectPhotoButtonPressed:(UIButton *)sender {
  if (self.delegate)
    [self.delegate cell:self selectPhotoButtonPressed:sender];
}

@end
