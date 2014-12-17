//
//  DFBadgeView.m
//  Strand
//
//  Created by Henry Bridge on 12/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFBadgeView.h"

@interface DFBadgeView()

@end

@implementation DFBadgeView

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.backgroundColor = [UIColor clearColor];
}


- (void)setBadgeImages:(NSArray *)badgeImages
{
  _badgeImages = badgeImages;
  [self setNeedsLayout];
  [self invalidateIntrinsicContentSize];
}

- (void)setBadgeSizes:(NSArray *)badgeSizes
{
  _badgeSizes = badgeSizes;
  [self setNeedsLayout];
  [self invalidateIntrinsicContentSize];
}

- (void)setBadgeColors:(NSArray *)badgeColors
{
  _badgeColors = badgeColors;
  [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
  [super drawRect:rect];
  
  for (NSUInteger i = 0; i < self.badgeImages.count; i++) {
    UIImage *image = self.badgeImages[i];
    CGRect badgeFrame = [self frameForBadgeAtIndex:i inRect:rect];
    [image drawInRect:badgeFrame];
  }
  
}

- (CGRect)frameForBadgeAtIndex:(NSUInteger)index inRect:(CGRect)rect
{
  CGFloat originX;
  if (index == 0) originX = 0.0;
  else {
    CGRect previousFrame =
    [self frameForBadgeAtIndex:index - 1 inRect:rect];
    originX = CGRectGetMaxX(previousFrame) + self.horizontalSpacing;
  }
  
  CGSize size = CGSizeZero;
  if (index < self.badgeSizes.count) {
    NSValue *sizeValue = self.badgeSizes[index];
    size = [sizeValue CGSizeValue];
  }
  
  return CGRectMake(originX, 0, size.width, size.height);
}


- (CGSize)sizeThatFits:(CGSize)size
{
  if (self.badgeImages.count == 0) return CGSizeZero;
  CGFloat maxHeight = 0;
  for (NSValue *sizeValue in self.badgeSizes) {
    CGSize size = [sizeValue CGSizeValue];
    if (size.height > maxHeight) maxHeight = size.height;
  }
  CGRect lastRect = [self frameForBadgeAtIndex:self.badgeImages.count - 1 inRect:CGRectMake(0, 0, 0, maxHeight)];
  return CGSizeMake(CGRectGetMaxX(lastRect), maxHeight);
}

- (CGSize)intrinsicContentSize
{
  CGSize sizeThatFits = [self sizeThatFits:CGSizeZero];
  return sizeThatFits;
}

@end
