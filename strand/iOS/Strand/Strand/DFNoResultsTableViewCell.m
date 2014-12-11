//
//  DFNoResultsTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 10/26/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNoResultsTableViewCell.h"

@implementation DFNoResultsTableViewCell

- (void)awakeFromNib {
  [super awakeFromNib];
  self.selectionStyle = UITableViewCellSelectionStyleNone;
}

+ (CGFloat)desiredHeight
{
  return 56.0;
}

@end
