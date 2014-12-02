//
//  DFPhotoFeedFooterCell.m
//  Strand
//
//  Created by Henry Bridge on 11/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedFooterCell.h"

@implementation DFPhotoFeedFooterCell

- (void)awakeFromNib {
  [super awakeFromNib];
  [self.commentButton setImage:[UIImage imageNamed:@"Assets/Icons/CommentButtonIcon"]
                      forState:UIControlStateNormal];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+ (CGFloat)height
{
  return 53.0;
}


- (IBAction)commentButtonPressed:(id)sender {
  if (self.commentBlock) self.commentBlock();
}

- (IBAction)moreButtonPressed:(id)sender {
  if (self.moreBlock) self.moreBlock();
}

- (IBAction)likeButtonPressed:(id)sender {
  if (self.likeBlock) self.likeBlock();
}

- (void)setLiked:(BOOL)liked
{
  if (liked) {
    [self.likeButton setTitle:@"Liked" forState:UIControlStateNormal];
    [self.likeButton setBackgroundColor:[UIColor darkGrayColor]];
    [self.likeButton setImage:[[UIImage imageNamed:@"Assets/Icons/LikeOnButtonIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                               forState:UIControlStateNormal];
  } else {
    [self.likeButton setTitle:@"Like" forState:UIControlStateNormal];
    [self.likeButton setBackgroundColor:[UIColor lightGrayColor]];
    [self.likeButton setImage:[UIImage imageNamed:@"Assets/Icons/LikeOffButtonIcon"]
                               forState:UIControlStateNormal];
  }
  [self.likeButton sizeToFit];
  [self setNeedsLayout];
}


@end
