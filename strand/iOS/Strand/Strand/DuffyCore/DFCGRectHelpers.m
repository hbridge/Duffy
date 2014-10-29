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

/* Calculates the amount that the originalSize would need to be scaled to 
 so that fittingSize perfectly matches one of originalSize's dimensions and the other
 is >= to the other fittingSize's dimension 
 
 Useful for calculating the non-stretched size of an image that must be loaded so it can be
 cropped down to fittingSize
 */

+ (CGSize)aspectScaledSize:(CGSize)originalSize fittingSize:(CGSize)fittingSize
{
  CGFloat originalAspect = originalSize.width / originalSize.height; //aspect = width/height
  CGFloat fittingSizeAspect = fittingSize.width / fittingSize.height;
  
  CGSize result = CGSizeZero;
  if (originalAspect > fittingSizeAspect) {
    // the original is wider than the fittingSize, the height will be the determining factor
    result.height = fittingSize.height;
    result.width = originalAspect * fittingSize.height; // width = aspect * height
  } else if (originalAspect < fittingSizeAspect) {
    // the original is taller than the fittingSize, the width will be the determining factor
    result.width = fittingSize.width;
    result.height = fittingSize.width / originalAspect; // height = width/aspect
  } else {
    // (originalAspect == fittingSizeAspect)
    result = fittingSize;
  }
  
  return result;
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
