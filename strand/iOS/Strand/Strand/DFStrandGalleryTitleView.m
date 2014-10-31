//
//  DFStrandGalleryTitleView.m
//  Strand
//
//  Created by Henry Bridge on 9/26/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandGalleryTitleView.h"

@implementation DFStrandGalleryTitleView

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.backgroundColor = [UIColor clearColor];
  self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
  self.autoresizesSubviews = YES;
}

@end
