//
//  DFCommentTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 11/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCommentTableViewCell.h"

@implementation DFCommentTableViewCell

- (void)awakeFromNib {
  self.profilePhotoStackView.backgroundColor = [UIColor clearColor];
  self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (CGFloat)rowHeight
{
  CGFloat height = [self.contentView
                    systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height + 1.0;
  
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

@end
