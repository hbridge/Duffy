//
//  DFSwapUpsellView.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapUpsellView.h"

@implementation DFSwapUpsellView


- (void)awakeFromNib
{
  [super awakeFromNib];
  self.backgroundColor = [UIColor clearColor];
  self.gradientColors = @[
                          [UIColor clearColor],
                          [UIColor colorWithWhite:1.0 alpha:0.9],
                          [UIColor colorWithWhite:1.0 alpha:0.98],
                          ];
}


- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  if (CGRectContainsPoint(self.matchMyPhotosButton.frame, point)) {
    return YES;
  }
  return NO;
}

- (void)configureWithSwappablePhotos:(BOOL)arePhotosSwappable buttonTarget:(id)target selector:(SEL)selector
{
  if (arePhotosSwappable) {
    self.upsellTitleLabel.text = @"You Have Matching Photos to Swap";
    [self.matchMyPhotosButton setTitle:@"Match my Photos"
                              forState:UIControlStateNormal];
  } else {
    self.upsellTitleLabel.text = @"No Matching Photos to Swap";
    [self.matchMyPhotosButton setTitle:@"View Photos"
                              forState:UIControlStateNormal];

  }
  [self.matchMyPhotosButton addTarget:target
                                action:selector
                      forControlEvents:UIControlEventTouchUpInside];
}

@end
