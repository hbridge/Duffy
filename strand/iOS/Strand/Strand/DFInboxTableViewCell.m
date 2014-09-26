//
//  DFActivityFeedTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 9/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInboxTableViewCell.h"

CGFloat const ActivityFeedTableViewCellNoCollectionViewHeight = 51;
CGFloat const ActivtyFeedTableViewCellCollectionViewRowHeight = 148;
CGFloat const ActivtyFeedTableViewCellCollectionViewRowSeparatorHeight = 8;

@implementation DFInboxTableViewCell

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (UIEdgeInsets)layoutMargins
{
  return UIEdgeInsetsZero;
}


- (void)configureForInboxCellStyle:(DFInboxCellStyle)style
{
  if (style == DFInboxCellStyleStrand) {
    [self.actorLabel removeFromSuperview];
    [self.actionTextLabel removeFromSuperview];
  }
}

+ (DFInboxTableViewCell *)createWithStyle:(DFInboxCellStyle)style {
  DFInboxTableViewCell *cell = [[[UINib nibWithNibName:NSStringFromClass([self class])
                                                bundle:nil]
                                 instantiateWithOwner:nil options:nil]
                                firstObject];
  [cell configureForInboxCellStyle:style];
  return cell;
}

@end
