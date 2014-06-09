//
//  DFPhotoView.m
//  Duffy
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoView.h"

@implementation DFPhotoView

@synthesize image = _image;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
      self.frame = frame;
      [self configureViews];
    }
    return self;
}

- (void)awakeFromNib
{
  [self configureViews];
}

- (void)configureViews
{
  self.scrollView = [[UIScrollView alloc] initWithFrame:self.frame];
  self.imageView = [[UIImageView alloc] initWithFrame:self.frame];
  [self.scrollView addSubview:self.imageView];
  self.imageView.image = _image;
  self.imageView.contentMode = UIViewContentModeScaleAspectFit;
  self.scrollView.delegate = self;
  self.scrollView.maximumZoomScale = 2.0;
  
  [self addSubview:self.scrollView];
}

- (void)setImage:(UIImage *)image
{
  _image = image;
  self.imageView.image = image;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv
{
  if (sv == self.scrollView) return self.imageView;
  
  return nil;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.scrollView.frame = self.frame;
  self.imageView.frame = self.frame;
}


@end
