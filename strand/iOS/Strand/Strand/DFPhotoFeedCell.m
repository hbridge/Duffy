//
//  DFPhotoFeedCell.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedCell.h"

@interface DFPhotoFeedCell()

@property (nonatomic, retain) NSMutableArray *favoritersConstraints;

@end

@implementation DFPhotoFeedCell

- (void)awakeFromNib
{
  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  self.favoritersButton.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
  [self saveConstraints];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.imageView.frame = self.imageViewPlaceholder.frame;
  self.imageView.clipsToBounds = YES;
}

- (void)setFavoritersListHidden:(BOOL)hidden
{
  if (hidden) {
    [self.favoritersButton removeFromSuperview];
  } else {
    if (!self.favoritersButton.superview || !self.favoritersButton) {
      DDLogVerbose(@"Re adding favoriters button: %@", self.favoritersButton);
      [self.contentView addSubview:self.favoritersButton];
      [self loadConstraints];
    }
  }
}

- (void)saveConstraints
{
  self.favoritersConstraints = [NSMutableArray new];
  for (NSLayoutConstraint *con in self.contentView.constraints) {
    if (con.firstItem == self.favoritersButton || con.secondItem == self.favoritersButton) {
      [self.favoritersConstraints addObject:con];
    }
  }
}

- (void)loadConstraints
{
  for (NSLayoutConstraint *con in self.favoritersConstraints) {
    [self.contentView addConstraint:con];
  }
}

@end
