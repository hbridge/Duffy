//
//  DFTopBannerView.m
//  Strand
//
//  Created by Henry Bridge on 12/2/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFTopBannerView.h"

@implementation DFTopBannerView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (IBAction)actionButtonPressed:(id)sender
{
  if (self.actionButtonHandler) self.actionButtonHandler();
}
@end
