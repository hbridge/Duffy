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
    self.upsellTitleLabel.text = @"You May Have Photos to Swap";
    [self.matchMyPhotosButton setTitle:@"Match my Photos"
                              forState:UIControlStateNormal];

  }
  [self.matchMyPhotosButton addTarget:target
                                action:selector
                      forControlEvents:UIControlEventTouchUpInside];
  self.activityWrapper.hidden = YES;
}


- (void)configureForContactsWithError:(BOOL)error
                         buttonTarget:(id)target
                                    selector:(SEL)selector
{
  if (!error) {
    self.upsellTitleLabel.text = @"Find More Friends to Swap With";
  } else {
    self.upsellTitleLabel.text = @"Contacts Permission Denied";
  }
  [self.matchMyPhotosButton setTitle:@"Grant Contacts Access"
                            forState:UIControlStateNormal];
  [self.matchMyPhotosButton addTarget:target
                               action:selector
                     forControlEvents:UIControlEventTouchUpInside];
}

- (void)configureActivityWithVisibility:(BOOL)visible
{
  if (visible) {
    self.matchMyPhotosButton.hidden = YES;
    self.activityWrapper.hidden = NO;
  } else {
    self.matchMyPhotosButton.hidden = NO;
    self.activityWrapper.hidden = YES;
  }
}

- (BOOL)isMatchingActivityOn
{
  return !self.activityWrapper.hidden;
}

@end
