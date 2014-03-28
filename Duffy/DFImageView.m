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

@synthesize boundingBoxesInImage;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setBoundingBoxesInImage:(NSArray *)newBoundingBoxesInImage
{
    boundingBoxesInImage = newBoundingBoxesInImage;
    for (NSValue *boundingBoxValue in newBoundingBoxesInImage) {
        CGRect boundingBox = boundingBoxValue.CGRectValue;
        CGRect scaledBoundingBox = [self scaleImageBoundingBoxToLocalCoordinates:boundingBox];

        DFBoundingBoxView *boundingBoxView = [[DFBoundingBoxView alloc] initWithFrame:scaledBoundingBox];
        [self addSubview:boundingBoxView];
        [self.boundingBoxSubviews addObject:boundingBoxView];
    }
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect
//{
//    [super drawRect:rect];
//    
//    if (!self.boundingBoxesInImage) return;
//    
//    // setup
//    float VerticalPadding = 2;
//    float HorizontalPadding = 2;
//    
//    CGContextRef ctx = UIGraphicsGetCurrentContext();
//    CGContextSetLineWidth(ctx, 1.0);
//    CGContextSetStrokeColorWithColor(ctx, [[UIColor redColor] CGColor]);
//    
//    for (NSValue *boundingBoxValue in self.boundingBoxesInImage) {
//        CGRect boundingBox = boundingBoxValue.CGRectValue;
//        NSLog(@"boundingBox: %@", NSStringFromCGRect(boundingBox));
//        CGRect scaledBoundingBox = [self scaleImageBoundingBoxToLocalCoordinates:boundingBox];
//        NSLog(@"scaledBoundingBox: %@", NSStringFromCGRect(scaledBoundingBox));
//        CGRect rectToStroke = CGRectInset(scaledBoundingBox, HorizontalPadding + 0.5, VerticalPadding + 0.5);
//
//        // rounded rect at border
//        UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:rectToStroke cornerRadius:5];
//        CGContextAddPath(ctx, roundedRect.CGPath);
//        CGContextStrokePath(ctx);
//    }
//}


- (CGRect)scaleImageBoundingBoxToLocalCoordinates:(CGRect)originalBoundingBox
{
    // figure out how much the image is scaled by
    if (self.contentMode == UIViewContentModeScaleAspectFit) {
        CGRect displayedImageRect = [DFCGRectHelpers aspectFittedSize:self.image.size max:[[UIScreen mainScreen] bounds]];
        
        NSLog(@"UIImageOrientation %d", self.image.imageOrientation);
        NSLog(@"originalBoundingBox: %@ in image size: %@", NSStringFromCGRect(originalBoundingBox), NSStringFromCGSize(self.image.size));
        CGAffineTransform transform;
        CGRect flippedBoundingBox;
        
        if (self.image.imageOrientation == UIImageOrientationUp ||
            self.image.imageOrientation == UIImageOrientationDown ||
            self.image.imageOrientation == UIImageOrientationDownMirrored) {
            transform = CGAffineTransformMakeScale(-1, 1);
            transform = CGAffineTransformTranslate(transform,
                                        -self.image.size.width, 0);
            flippedBoundingBox = CGRectApplyAffineTransform(originalBoundingBox, transform);
        } else if (self.image.imageOrientation == UIImageOrientationLeft ||
                   self.image.imageOrientation == UIImageOrientationRight) {
            flippedBoundingBox = CGRectMake(originalBoundingBox.origin.y, originalBoundingBox.origin.x, originalBoundingBox.size.height, originalBoundingBox.size.width);
        }
        

        NSLog(@"flippedBoundingBox: %@", NSStringFromCGRect(flippedBoundingBox));
        
        CGFloat xScale = displayedImageRect.size.width / self.image.size.width;
        CGFloat yScale = displayedImageRect.size.height / self.image.size.height;
        transform = CGAffineTransformMakeScale(xScale, yScale);
        
        
        NSLog(@"yscale = %.02f", yScale);
        CGRect scaledBoundingBox = CGRectApplyAffineTransform(flippedBoundingBox, transform);
        
        NSLog(@"scaledBoundingBox: %@ in image size %@", NSStringFromCGRect(scaledBoundingBox), NSStringFromCGSize(displayedImageRect.size));
        
        CGRect translatedUpsideDownDisplayedImage = CGRectMake(displayedImageRect.origin.x + scaledBoundingBox.origin.x,
                                                                    displayedImageRect.origin.y + scaledBoundingBox.origin.y,
                                                                    scaledBoundingBox.size.width,
                                                                    scaledBoundingBox.size.width);
        NSLog(@"translatedUpsideDownDisplayedImage: %@ in image frame %@", NSStringFromCGRect(translatedUpsideDownDisplayedImage), NSStringFromCGRect(displayedImageRect));
        
        
        return translatedUpsideDownDisplayedImage;
    }
    
    return CGRectZero;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    //NSLog(@"self frame changes:%@", NSStringFromCGRect(self.frame));
    //NSLog(@"scale factor: %.02f",self.contentScaleFactor);
}

@end
