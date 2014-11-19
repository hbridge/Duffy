//
//  DFPhotoFeedImageCellTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 11/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedImageCell.h"

@implementation DFPhotoFeedImageCell

- (void)awakeFromNib {
  [super awakeFromNib];
  UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(doubleTapped:)];
  doubleTapRecognizer.numberOfTapsRequired = 2;
  [self.photoImageView addGestureRecognizer:doubleTapRecognizer];
}

+ (CGFloat)imageViewHeightForReferenceWidth:(CGFloat)referenceWidth
                                     aspect:(DFPhotoFeedImageCellAspect)aspect
{
  CGFloat height = 0.0;
  if (aspect == DFPhotoFeedImageCellAspectSquare) {
    height = referenceWidth;
  } else if (aspect == DFPhotoFeedImageCellAspectPortrait) {
    height = referenceWidth * (4.0/3.0);
  } else if (aspect == DFPhotoFeedImageCellAspectLandscape) {
    height = referenceWidth * (3.0/4.0);
  }
  return height;
}

- (void)doubleTapped:(UITapGestureRecognizer *)sender {
  if (self.doubleTapBlock) self.doubleTapBlock();
}

@end
