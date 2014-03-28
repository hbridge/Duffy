//
//  DFBoundingBoxView.m
//  Duffy
//
//  Created by Henry Bridge on 3/27/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFBoundingBoxView.h"

@implementation DFBoundingBoxView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    float VerticalPadding = 2;
    float HorizontalPadding = 2;
    
    // setup
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect rectToStroke = CGRectInset(rect, HorizontalPadding + 0.5, VerticalPadding + 0.5);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextSetStrokeColorWithColor(ctx, [[UIColor redColor] CGColor]);
    
    // rounded rect at border
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:rectToStroke cornerRadius:8];
    CGContextAddPath(ctx, roundedRect.CGPath);
    CGContextStrokePath(ctx);
}


@end
