//
//  DFNotificationTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNotificationTableViewCell.h"

@implementation DFNotificationTableViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];
  self.previewImageView.layer.cornerRadius = 3.0;
  self.previewImageView.layer.masksToBounds = YES;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+ (DFNotificationTableViewCell *)templateCell
{
  return [UINib instantiateViewWithClass:[self class]];
}

- (CGFloat)rowHeight
{
  CGFloat height = [self.contentView
                    systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height + 1.0;
  
  return height;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.detailLabel.preferredMaxLayoutWidth = self.detailLabel.frame.size.width;
}


@end
