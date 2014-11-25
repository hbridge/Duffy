//
//  DFRequestNotificationView.m
//  Strand
//
//  Created by Henry Bridge on 11/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFRequestNotificationView.h"

@implementation DFRequestNotificationView

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.profileWithContextView.titleLabel.textColor = [UIColor whiteColor];
  self.profileWithContextView.subtitleLabel.textColor = [UIColor whiteColor];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
