//
//  DFPhotoViewCell.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoViewCell.h"


@implementation DFPhotoViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.contentView.translatesAutoresizingMaskIntoConstraints = YES;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


@end
