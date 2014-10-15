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
  self.layer.cornerRadius = 3.0;
  self.layer.masksToBounds = YES;
  self.backgroundColor = [DFStrandConstants defaultBackgroundColor];
  [self setTitleColor:[DFStrandConstants defaultBarForegroundColor] forState:UIControlStateNormal];
}

- (void)layoutSubviews
{
  self.contentEdgeInsets = UIEdgeInsetsMake(10.0, 20.0, 10.0, 20.0);
  
  [super layoutSubviews];
}

@end
