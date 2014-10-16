//
//  DFNoTableItemsLabel.m
//  Strand
//
//  Created by Henry Bridge on 10/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNoTableItemsLabel.h"

@implementation DFNoTableItemsLabel

- (instancetype)initWithSuperView:(UIView *)superview
{
  self = [super init];
  if (self) {
    [self configureWithSuperView:superview];
  }
  return self;
}

- (void)awakeFromNib
{
  [self configureWithSuperView:self.superview];
}

- (void)configureWithSuperView:(UIView *)superView
{
  if (!self.superview) {
    [superView addSubview:self];
  }
  self.text = @"No Photos";
  self.font = [UIFont systemFontOfSize:19];
  self.textColor = [UIColor darkGrayColor];
  self.textAlignment = NSTextAlignmentCenter;
  CGRect frame = superView.frame;
  frame.size.height = frame.size.height / 2.0;
  self.frame = frame;
}

@end
