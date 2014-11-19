//
//  DFPhotoFeedFooterCell.m
//  Strand
//
//  Created by Henry Bridge on 11/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedFooterCell.h"

@implementation DFPhotoFeedFooterCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+ (CGFloat)height
{
  return 53.0;
}


- (IBAction)commentButtonPressed:(id)sender {
  self.commentBlock();
}

- (IBAction)moreButtonPressed:(id)sender {
  self.moreBlock();
}


@end
