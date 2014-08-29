//
//  DFSelectablePhotoViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectablePhotoViewCell.h"

@implementation DFSelectablePhotoViewCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setShowTickMark:(BOOL)showTickMark
{
  self.selectedImageView.hidden = !showTickMark;
  [self setNeedsLayout];
}

- (BOOL)showTickMark
{
  return !self.selectedImageView.hidden;
}

@end
