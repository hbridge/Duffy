//
//  DFButtonTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 12/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFButtonTableViewCell.h"

@implementation DFButtonTableViewCell

- (void)awakeFromNib {
  self.button.userInteractionEnabled = NO;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [super setSelected:selected animated:animated];
  
  // Configure the view for the selected state
}

@end
