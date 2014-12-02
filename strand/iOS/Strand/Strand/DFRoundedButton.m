//
//  DFRoundedButton.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFRoundedButton.h"

@implementation DFRoundedButton


- (void)layoutSubviews
{
  [super layoutSubviews];
  self.layer.cornerRadius = self.cornerRadius;
  self.layer.masksToBounds = YES;
  if (self.borderColor) {
    self.layer.borderColor = self.borderColor.CGColor;
    self.layer.borderWidth = self.borderWidth;
  }
  
}


@end
