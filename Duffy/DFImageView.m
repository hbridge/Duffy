//
//  DFImageView.m
//  Duffy
//
//  Created by Henry Bridge on 3/27/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFImageView.h"
#import "DFCGRectHelpers.h"
#import "DFBoundingBoxView.h"

@interface DFImageView()

@property (nonatomic, retain) NSMutableArray *boundingBoxSubviews;

@end

@implementation DFImageView

@synthesize boundingBoxesInImageCoordinates;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setBoundingBoxesInImageCoordinates:(NSArray *)newBoundingBoxesInImageCoordinates
{
    boundingBoxesInImageCoordinates = newBoundingBoxesInImageCoordinates;
    for (NSValue *boundingBoxValue in boundingBoxesInImageCoordinates) {
        CGRect boundingBox = boundingBoxValue.CGRectValue;
        CGRect scaledBoundingBox = [self scaleImageBoundingBoxToLocalCoordinates:boundingBox];

        DFBoundingBoxView *boundingBoxView = [[DFBoundingBoxView alloc] initWithFrame:scaledBoundingBox];
        [self addSubview:boundingBoxView];
        [self.boundingBoxSubviews addObject:boundingBoxView];
    }
}

- (CGRect)scaleImageBoundingBoxToLocalCoordinates:(CGRect)originalBoundingBox
{
    if (self.contentMode == UIViewContentModeScaleAspectFit) {
        CGRect displayedImageRect = [DFCGRectHelpers aspectFittedSize:self.image.size max:[[UIScreen mainScreen] bounds]];
        
        // flip the y coordinate space because core image uses bottom left and UIKit uses top left
        CGRect flippedBoundingBox;
        CGAffineTransform transform = CGAffineTransformMakeScale(1, -1);
        transform = CGAffineTransformTranslate(transform,
                                               0, -self.image.size.height);
        flippedBoundingBox = CGRectApplyAffineTransform(originalBoundingBox, transform);
        
        // scale it to the actual image displayed location
        CGFloat xScale = displayedImageRect.size.width / self.image.size.width;
        CGFloat yScale = displayedImageRect.size.height / self.image.size.height;
        transform = CGAffineTransformMakeScale(xScale, yScale);
        CGRect scaledBoundingBox = CGRectApplyAffineTransform(flippedBoundingBox, transform);
        
        // translate the bounding box over the acutal display image
        transform = CGAffineTransformMakeTranslation(displayedImageRect.origin.x, displayedImageRect.origin.y);
        CGRect translatedScaledBoundingBox = CGRectApplyAffineTransform(scaledBoundingBox, transform);
        
        return translatedScaledBoundingBox;
    }
    
    return CGRectZero;
}

@end
