//
//  DFCGRectHelpers.m
//  Duffy
//
//  Created by Henry Bridge on 3/27/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCGRectHelpers.h"

@implementation DFCGRectHelpers


+ (CGRect) aspectFittedSize:(CGSize)inSize max:(CGRect)maxRect
{
	float originalAspectRatio = inSize.width / inSize.height;
	float maxAspectRatio = maxRect.size.width / maxRect.size.height;
    
	CGRect newRect = maxRect;
	if (originalAspectRatio > maxAspectRatio) { // scale by width
		newRect.size.height = maxRect.size.width * (inSize.height / inSize.width);
		newRect.origin.y += (maxRect.size.height - newRect.size.height)/2.0;
	} else {
		newRect.size.width = maxRect.size.height  * inSize.width / inSize.height;
		newRect.origin.x += (maxRect.size.width - newRect.size.width)/2.0;
	}
    
	return CGRectIntegral(newRect);
}


+ (CGSize)scaledSize:(CGSize)originalSize withNewSmallerDimension:(CGFloat)length
{
  CGSize newSize;
  if (originalSize.height < originalSize.width) {
    CGFloat scaleFactor = length/originalSize.height;
    newSize = CGSizeMake(ceil(originalSize.width * scaleFactor), length);
  } else {
    CGFloat scaleFactor = length/originalSize.width;
    newSize = CGSizeMake(length, ceil(originalSize.height * scaleFactor));
  }
  
  return newSize;
}

@end
