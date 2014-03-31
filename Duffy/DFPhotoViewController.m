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
#import "DFPhoto+FaceDetection.h"

@interface DFPhotoViewController ()

@end

@implementation DFPhotoViewController

- (id)init
{
    self = [super initWithNibName:@"DFPhotoViewController" bundle:nil];
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
    if (self.imageView && self.photo) {
        self.imageView.image = self.photo.fullScreenImage;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPhoto:(DFPhoto *)photo
{
    _photo = photo;
    
    if (self.imageView) {
        self.imageView.image = photo.fullScreenImage;
    }
}



- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv
{
    if (sv == self.scrollView) return self.imageView;
    
    return nil;
}


- (void)addFaceBoundingBoxes
{
    // if there are already bounding boxes in the image view, we've already
    // done recognition, skip it
    if (self.imageView.boundingBoxesInImageCoordinates) return;

    [self.photo faceFeaturesInPhoto:^(NSArray *features) {
        NSMutableArray *boundingBoxes = [[NSMutableArray alloc] init];
    
        for (CIFaceFeature *f in features)
        {
            NSLog(@"face found at %@", NSStringFromCGRect(f.bounds));
            [boundingBoxes addObject:[NSValue valueWithCGRect:f.bounds]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.boundingBoxesInImageCoordinates = boundingBoxes;
        });
    }];
}



@end
