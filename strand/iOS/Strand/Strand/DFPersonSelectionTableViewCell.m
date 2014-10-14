//
//  DFPersonSelectionTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPersonSelectionTableViewCell.h"

@implementation DFPersonSelectionTableViewCell

- (void)awakeFromNib {
    // Initialization code
  UIView *backgroundColorView = [[UIView alloc] init];
  backgroundColorView.backgroundColor = [UIColor colorWithWhite:.95 alpha:1.0];
  self.selectedBackgroundView = backgroundColorView;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [super setSelected:selected animated:animated];
  [self configureChecked];
}

- (void)configureChecked
{
  if (self.isSelected) {
    self.accessoryType = UITableViewCellAccessoryCheckmark;
  } else {
    self.accessoryType = UITableViewCellAccessoryNone;
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self configureChecked];
  
}

- (void)configureWithCellStyle:(DFPersonSelectionTableViewCellStyle)style {
  if (style == DFPersonSelectionTableViewCellStyleStrandUser) {
    [self.subtitleLabel removeFromSuperview];
  } else if (style == DFPersonSelectionTableViewCellStyleNonUser) {
    [self.profilePhotoStackView removeFromSuperview];
  }
}

@end
