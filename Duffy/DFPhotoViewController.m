//
//  DFPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoViewController.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "DFBoundingBoxView.h"
#import "UIImage+DFHelpers.h"
#import "DFPhoto.h"

@interface DFPhotoViewController ()

@end

@implementation DFPhotoViewController

- (id)init
{
    self = [super init];
    if (self) {
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Photo"];
        
        
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.imageView.image = self.image;
    [self.imageView sizeToFit];
    
    [self addFaceBoundingBoxes];
}


- (void)viewDidAppear:(BOOL)animated
{

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setImage:(UIImage *)newImage
{
    _image = newImage;
    
    self.imageView.image = newImage;
}


- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv
{
    if (sv == self.scrollView) return self.imageView;
    
    return nil;
}


- (void)addFaceBoundingBoxes
{
    CIImage *ciImage = [self.photo CIImageForFullImage];
    
    CIContext *context = [CIContext contextWithOptions:nil];                    // 1
    NSDictionary *opts = @{ CIDetectorAccuracy : CIDetectorAccuracyHigh };      // 2
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:context
                                              options:opts];                    // 3
    
    if ([ciImage.properties valueForKey:(NSString *)kCGImagePropertyOrientation]) {
        opts = @{ CIDetectorImageOrientation : [ciImage.properties valueForKey:(NSString *)kCGImagePropertyOrientation] }; // 4
    } else {
        opts = @{};
    }
    
        
    NSArray *features = [detector featuresInImage:ciImage options:opts];
    NSMutableArray *boundingBoxes = [[NSMutableArray alloc] init];
    
    for (CIFaceFeature *f in features)
    {
        NSLog(@"face found at %@ in photo with properties:%@", NSStringFromCGRect(f.bounds), ciImage.properties);
        [boundingBoxes addObject:[NSValue valueWithCGRect:f.bounds]];
    }
    
    self.imageView.boundingBoxesInImage = boundingBoxes;
    [self.imageView setNeedsDisplay];

    
}


@end
