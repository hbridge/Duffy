//
//  DFOutlineSubviewsView.m
//  Strand
//
//  Created by Henry Bridge on 10/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFOutlineSubviewsView.h"

@implementation DFOutlineSubviewsView


- (void)drawRect:(CGRect)rect {
  [super drawRect:rect];
  
  for (UIView *subview in self.subviews) {
    CGRect solidFrame = subview.frame;
    solidFrame = CGRectInset(solidFrame, -0.5, -0.5);
    // setup
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, self.outlineThickness);
    CGContextSetStrokeColorWithColor(ctx, [self.outlineColor CGColor]);
    
    // rounded rect at border
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:solidFrame
                                                           cornerRadius:self.outlineCornerRadius];
    CGContextAddPath(ctx, roundedRect.CGPath);
    CGContextStrokePath(ctx);
  }
}

@end
