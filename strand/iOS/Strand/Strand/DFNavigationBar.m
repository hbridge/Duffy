//
//  DFNavigationbar.m
//  Strand
//
//  Created by Henry Bridge on 7/27/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNavigationBar.h"

@implementation DFNavigationBar

- (void)layoutSubviews
{
  [super setFrame:CGRectMake(self.frame.origin.x, 0, self.frame.size.width, 64)];
  [super layoutSubviews];
}


@end
