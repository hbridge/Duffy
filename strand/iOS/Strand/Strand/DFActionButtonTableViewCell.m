//
//  DFActionButtonTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 10/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFActionButtonTableViewCell.h"

@implementation DFActionButtonTableViewCell

- (void)awakeFromNib {
  self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [self.actionButton setSelected:selected];
}

@end
