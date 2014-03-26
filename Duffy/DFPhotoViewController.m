//
//  DFPhotoViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoViewController.h"

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
    [self.imageView sizeToFit];
    
    
}


- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv
{
    if (sv == self.scrollView) return self.imageView;
    
    return nil;
}


@end
