//
//  DFSwapTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 10/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapTableViewCell.h"


@implementation DFSwapTableViewCell

- (void)awakeFromNib {
  self.previewImageView.layer.cornerRadius = 4.0;
  self.previewImageView.layer.masksToBounds = YES;
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+ (CGFloat)height
{
  return 69.0;
}

+ (UIEdgeInsets)edgeInsets
{
  return UIEdgeInsetsMake(0, 15, 0, 15);
}

@end
