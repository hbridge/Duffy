//
//  DFSwapAddPhotosCell.m
//  Strand
//
//  Created by Henry Bridge on 11/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapAddPhotosCell.h"

@implementation DFSwapAddPhotosCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)cancelPressed:(id)sender {
  if (self.cancelBlock) self.cancelBlock();
}

- (IBAction)okPressed:(id)sender {
  if (self.okBlock) self.okBlock();
}
@end
