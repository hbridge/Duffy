//
//  UIView+DFExtensions.h
//  Strand
//
//  Created by Henry Bridge on 8/11/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (DFExtensions)

@property (nonatomic, readonly) CGSize pixelSize;

- (UIImage *) imageRepresentation;
- (void)constrainToSuperviewSize;

@end
