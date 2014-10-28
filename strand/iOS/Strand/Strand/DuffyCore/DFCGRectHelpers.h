//
//  DFCGRectHelpers.h
//  Duffy
//
//  Created by Henry Bridge on 3/27/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFCGRectHelpers : NSObject

+ (CGRect) aspectFittedSize:(CGSize)originalSize max:(CGRect)maxRect;
+ (CGSize)aspectScaledSize:(CGSize)originalSize fittingSize:(CGSize)fittingSize;

@end
