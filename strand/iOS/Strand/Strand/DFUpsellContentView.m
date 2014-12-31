//
//  DFTwoLabelView.m
//  Strand
//
//  Created by Derek Parham on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUpsellContentView.h"

@implementation DFUpsellContentView

- (void)layoutSubviews
{
  [super layoutSubviews];
  // we have to set the preferred label to its actual width or it won't wrap
  if (self.bottomLabel.frame.size.width != self.bottomLabel.preferredMaxLayoutWidth) {
    self.bottomLabel.preferredMaxLayoutWidth = self.bottomLabel.frame.size.width;
    [self setNeedsLayout];
    [self layoutIfNeeded];
  }
}
@end
