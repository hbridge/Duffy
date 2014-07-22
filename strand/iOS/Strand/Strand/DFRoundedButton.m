//
//  DFRoundedButton.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFRoundedButton.h"

@implementation DFRoundedButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super init];
    if (self) {
      [self configureView];
    }
    return self;
}

- (void)awakeFromNib
{
  [self configureView];
}

- (void)configureView
{
  self.layer.cornerRadius = 7;
  if (self.imageView.image) {
    self.contentEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 6 + 4);
    self.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
  }
}

//- (void)setSelected:(BOOL)selected
//{
//  [super setSelected:selected];
//  CGSize sizeThatFits = [self sizeThatFits:self.frame.size];
//  DDLogVerbose(@"PRE  size: %@ sizeThatFits:%@", NSStringFromCGSize(self.frame.size), NSStringFromCGSize([self sizeThatFits:self.frame.size]));
//  self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, sizeThatFits.width, sizeThatFits.height);
//  DDLogVerbose(@"POST size: %@ sizeThatFits:%@", NSStringFromCGSize(self.frame.size), NSStringFromCGSize([self sizeThatFits:self.frame.size]));
//}

- (CGSize)sizeThatFits:(CGSize)size
{
  CGSize normal = [super sizeThatFits:size];
  return CGSizeMake(normal.width + 6 + 6 + 4, normal.height);
}


@end
