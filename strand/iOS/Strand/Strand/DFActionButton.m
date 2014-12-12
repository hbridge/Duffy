//
//  DFActionButton.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFActionButton.h"
#import "DFStrandConstants.h"

@implementation DFActionButton

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configure];
  }
  return self;
}


- (void)awakeFromNib
{
  [self configure];
}

- (void)configure
{
  if (_cornerRadius == 0) self.cornerRadius = 3.0;
  self.layer.cornerRadius = _cornerRadius;
  self.layer.masksToBounds = YES;
  self.backgroundColor = [DFStrandConstants actionButtonBackgroundColor];
  [self setTitleColor:[DFStrandConstants actionButtonForegroundColor] forState:UIControlStateNormal];
}

- (void)layoutSubviews
{
  self.contentEdgeInsets = UIEdgeInsetsMake(10.0, 20.0, 10.0, 20.0);
  
  [super layoutSubviews];
}

- (void)setEnabled:(BOOL)enabled
{
  [super setEnabled:enabled];
  if (enabled) {
    self.backgroundColor = [DFStrandConstants actionButtonBackgroundColor];
  } else {
    self.backgroundColor = [[DFStrandConstants actionButtonBackgroundColor] colorWithAlphaComponent:0.7];
  }
}

@end
