//
//  UIImageView+DFHelpers.m
//  Strand
//
//  Created by Henry Bridge on 9/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "UIImageView+DFHelpers.h"

@implementation UIImageView (DFHelpers)


- (void)setImageRenderingMode:(UIImageRenderingMode)renderMode
{
  NSAssert(self.image, @"Image must be set before setting rendering mode");
  self.image = [self.image imageWithRenderingMode:renderMode];
}

@end
