//
//  DFCommentTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 11/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCommentTableViewCell.h"

@interface DFCommentTableViewCell()

@property (nonatomic, retain) NSLayoutConstraint *widthConstraint;

@end

@implementation DFCommentTableViewCell

- (void)awakeFromNib {
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];
  self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (CGFloat)rowHeight
{
  [self layoutIfNeeded];
  CGSize fittingSize = [self.contentView
                        systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
  CGFloat height = fittingSize.height + 1.0;
  
  return height;
}

+ (DFCommentTableViewCell *)templateCell
{
  return [UINib instantiateViewWithClass:[self class]];
}

+ (UIEdgeInsets)edgeInsets
{
  return UIEdgeInsetsMake(0, 15, 0, 15);
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  // we have to set the preferred label to its actual width or it won't wrap
  if (self.commentLabel.frame.size.width != self.commentLabel.preferredMaxLayoutWidth) {
    self.commentLabel.preferredMaxLayoutWidth = self.commentLabel.frame.size.width;
    [self setNeedsLayout];
    [self layoutIfNeeded];
  }
  
}

@end
