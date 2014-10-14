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

@end
