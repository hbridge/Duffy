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
  [super awakeFromNib];
  [self configure];
}

- (void)configure
{
  if (_cornerRadius == 0) self.cornerRadius = 3.0;
  self.layer.cornerRadius = _cornerRadius;
  self.layer.masksToBounds = YES;
  if (!self.backgroundColor) {
    self.backgroundColor = [DFStrandConstants defaultBackgroundColor];
  }
  [self setTitleColor:[DFStrandConstants defaultBarForegroundColor] forState:UIControlStateNormal];
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
    self.backgroundColor = [DFStrandConstants defaultBackgroundColor];
  } else {
    self.backgroundColor = [[DFStrandConstants defaultBackgroundColor] colorWithAlphaComponent:0.7];
  }
}

@end
