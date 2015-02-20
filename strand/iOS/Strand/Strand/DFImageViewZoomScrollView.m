//
//  DFImageViewZoomScrollView.m
//  Strand
//
//  Created by Henry Bridge on 2/20/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFImageViewZoomScrollView.h"
#import "DFCGRectHelpers.h"

@implementation DFImageViewZoomScrollView

- (instancetype)init
{
  self = [super init];
  if (self) {
  }
  return self;
}

- (void)setImageView:(UIImageView *)imageView
{
  if (_imageView && _imageView != imageView) {
    [_imageView removeObserver:self forKeyPath:@"image"];
    [_imageView removeFromSuperview];
  }
  _imageView = imageView;
  
  self.delegate = self;
  self.maximumZoomScale = 3.0;
  [self addSubview:imageView];
  self.imageView.frame = self.bounds;
  
  [self.imageView addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionOld context:nil];
  
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv
{
  if (sv == self) return self.imageView;
  
  return nil;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
  [self updateContentSize];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (object == self.imageView && [keyPath isEqualToString:@"image"]){
    CGRect imageFrame = [DFCGRectHelpers aspectFittedSize:self.imageView.image.size max:self.bounds];
    imageFrame.origin = CGPointZero;
    self.imageView.frame = imageFrame;
    [self updateContentSize];
  }
}

- (void)updateContentSize
{
  CGRect imageFrame = [DFCGRectHelpers aspectFittedSize:self.imageView.image.size max:self.bounds];
  
  CGSize zoomedContentSize = CGSizeMake(imageFrame.size.width * self.zoomScale, imageFrame.size.height * self.zoomScale);
  DDLogVerbose(@"imageSize:%@ contentSize:%@", NSStringFromCGSize(self.imageView.image.size), NSStringFromCGSize(imageFrame.size));
  self.contentSize = zoomedContentSize;
  
  CGFloat xInset = MAX(self.frame.size.width - zoomedContentSize.width, 0);
  CGFloat yInset = MAX(self.frame.size.height - zoomedContentSize.height, 0);
  self.contentInset = UIEdgeInsetsMake(yInset/2.0,
                                       xInset,
                                       yInset/2.0,
                                       xInset);
}

- (void)dealloc
{
  [self.imageView removeObserver:self forKeyPath:@"image"];
}

@end
