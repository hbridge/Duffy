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

- (void)layoutSubviews
{
  self.contentEdgeInsets = UIEdgeInsetsMake(10.0, 20.0, 10.0, 20.0);
  
  [super layoutSubviews];
  self.layer.cornerRadius = 3.0;
  self.layer.masksToBounds = YES;
  self.backgroundColor = [DFStrandConstants defaultBackgroundColor];

}

@end
