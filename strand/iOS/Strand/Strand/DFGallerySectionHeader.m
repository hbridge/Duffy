//
//  DFGallerySectionHeader.m
//  Strand
//
//  Created by Henry Bridge on 8/18/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFGallerySectionHeader.h"

@implementation DFGallerySectionHeader

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
  self.profilePhotoStackView.shouldShowNameLabel = YES;
}

@end
