//
//  UIColor+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 10/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "UIColor+DFHelpers.h"

@implementation UIColor (DFHelpers)


+ (UIColor *)colorWithRedByte:(UInt8)red green:(UInt8)green blue:(UInt8)blue alpha:(CGFloat)alpha
{
  return [UIColor colorWithRed:((CGFloat)red)/255.0
                         green:((CGFloat)green)/255.0
                          blue:((CGFloat)blue)/255.0
                         alpha:alpha];
}

@end
