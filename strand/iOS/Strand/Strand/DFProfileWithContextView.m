//
//  DFProfileWithContextView.m
//  Strand
//
//  Created by Henry Bridge on 11/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFProfileWithContextView.h"

@implementation DFProfileWithContextView

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.profileStackView.backgroundColor = [UIColor clearColor];
  self.backgroundColor = [UIColor clearColor];
}

- (id)awakeAfterUsingCoder:(NSCoder *)aDecoder
{
  if (self.subviews.count == 0) {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIView *view = (DFProfileWithContextView *)[[bundle loadNibNamed:NSStringFromClass(self.class) owner:nil options:nil] firstObject];
    view.translatesAutoresizingMaskIntoConstraints = NO;
//    NSArray *constraints = self.constraints;
//    [self removeConstraints:constraints];
//    [view addConstraints:constraints];
    return view;
  }
  
  return self;
}

- (void)setTitle:(NSString *)title
{
  self.titleLabel.text = title;
}

- (NSString *)title
{
  return self.titleLabel.text;
}

- (void)setSubTitle:(NSString *)subTitle
{
  self.subtitleLabel.text = subTitle;
}

- (NSString *)subTitle
{
  return self.subtitleLabel.text;
}

@end
