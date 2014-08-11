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


@end
