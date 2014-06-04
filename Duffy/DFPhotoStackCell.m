//
//  DFPhotoStackCell.m
//  Duffy
//
//  Created by Henry Bridge on 6/3/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStackCell.h"

@implementation DFPhotoStackCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
  self.countLabel.font = [UIFont fontWithName:@"ProximaNova-Semibold" size:13];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
