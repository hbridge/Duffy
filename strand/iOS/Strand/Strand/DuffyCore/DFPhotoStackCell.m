//
//  DFPhotoStackCell.m
//  Duffy
//
//  Created by Henry Bridge on 6/3/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStackCell.h"

@implementation DFPhotoStackCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.contentView.translatesAutoresizingMaskIntoConstraints = YES;
}



@end
