//
//  DFBorderedTextField.m
//  Strand
//
//  Created by Henry Bridge on 2/10/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFBorderedTextField.h"

@implementation DFBorderedTextField

- (void)drawRect:(CGRect)rect
{
  [super drawRect:rect];
  
  CGColorRef color = self.borderColor.CGColor;
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(context, color);
  if (self.bottomBorder > 0.0) {
    CGRect borderRect = CGRectMake(0,
                                   CGRectGetMaxY(rect) - self.bottomBorder,
                                   CGRectGetMaxX(rect),
                                   self.bottomBorder);
    CGContextFillRect(context, borderRect);
  }
  
  if (self.leftBorder > 0.0) {
    CGRect borderRect = CGRectMake(0,
                                   0,
                                   self.leftBorder,
                                   CGRectGetMaxY(rect));
    CGContextFillRect(context, borderRect);
  }

  if (self.rightBorder > 0.0) {
    CGRect borderRect = CGRectMake(CGRectGetMaxX(rect) - self.rightBorder,
                                   0,
                                   self.rightBorder,
                                   CGRectGetMaxY(rect));
    CGContextFillRect(context, borderRect);
  }
  
  if (self.topBorder > 0.0) {
    CGRect borderRect = CGRectMake(0,
                                   0,
                                   CGRectGetMaxX(rect),
                                   self.topBorder);
    CGContextFillRect(context, borderRect);
  }
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
  CGRect rect = [super textRectForBounds:bounds];
  rect.origin.x = self.leftInset;
  rect.size.width -= self.leftInset;
  return rect;
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
  CGRect rect = [super editingRectForBounds:bounds];
  rect.origin.x = self.leftInset;
  rect.size.width -= self.leftInset;
  return rect;
}

@end
