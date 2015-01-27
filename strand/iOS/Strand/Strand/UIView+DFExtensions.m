//
//  UIView+DFExtensions.m
//  Strand
//
//  Created by Henry Bridge on 8/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "UIView+DFExtensions.h"

@implementation UIView (DFExtensions)

- (UIImage *) imageRepresentation
{
  UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, 0.0);
  [self.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
  
  UIGraphicsEndImageContext();
  
  return img;
}


- (CGSize)pixelSize
{
  CGSize unscaled = self.frame.size;
  CGSize scaled = CGSizeMake(unscaled.width * [[UIScreen mainScreen] scale],
                             unscaled.height * [[UIScreen mainScreen] scale]);
  return scaled;
}

- (void)constrainToSuperviewSize
{
  if (!self.superview) return;
  self.translatesAutoresizingMaskIntoConstraints = NO;
  [self.superview addConstraints:[NSLayoutConstraint
                                  constraintsWithVisualFormat:@"|-(0)-[self]-(0)-|"
                                  options:0
                                  metrics:nil
                                  views:@{@"self" : self}]];
  [self.superview addConstraints:[NSLayoutConstraint
                                  constraintsWithVisualFormat:@"V:|-(0)-[self]-(0)-|"
                                  options:0
                                  metrics:nil
                                  views:@{@"self" : self}]];
}


@end
