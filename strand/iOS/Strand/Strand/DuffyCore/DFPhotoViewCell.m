//
//  DFPhotoViewCell.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoViewCell.h"
#import <Slash/Slash.h>


@implementation DFPhotoViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.contentView.translatesAutoresizingMaskIntoConstraints = YES;
  self.countBadgeView.badgeColor = [DFStrandConstants strandRed];
  self.countBadgeView.textColor = [UIColor whiteColor];
  self.countBadgeView.widthMode = LKBadgeViewWidthModeSmall;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


- (void)setNumLikes:(NSUInteger)numLikes
        numComments:(NSUInteger)numComments
     numUnreadLikes:(NSUInteger)numUnreadLikes
  numUnreadComments:(NSUInteger)numUnreadComments
{
  if (numLikes == 0 && numComments == 0) {
    self.badgeView.badgeImages = nil;
    return;
  }
  
  NSMutableArray *badgeImages = [NSMutableArray new];
  NSMutableArray *badgeColors = [NSMutableArray new];
  NSMutableArray *badgeSizes = [NSMutableArray new];
  
  if (numUnreadComments > 0) {
    [badgeImages addObject:[UIImage imageNamed:@"Assets/Icons/CommentsUnreadIcon"]];
    [badgeColors addObject:[DFStrandConstants alertBackgroundColor]];
    [badgeSizes addObject:[NSValue valueWithCGSize:CGSizeMake(22.0, 22.0)]];
  } else if (numComments > 0) {
    [badgeImages addObject:[UIImage imageNamed:@"Assets/Icons/CommentsReadIcon"]];
    [badgeColors addObject:[UIColor whiteColor]];
    [badgeSizes addObject:[NSValue valueWithCGSize:CGSizeMake(13.0, 13.0)]];
  }
  
  if (numUnreadLikes > 0) {
    [badgeImages addObject:[UIImage imageNamed:@"Assets/Icons/LikesUnreadIcon"]];
    [badgeColors addObject:[DFStrandConstants alertBackgroundColor]];
    [badgeSizes addObject:[NSValue valueWithCGSize:CGSizeMake(22.0, 22.0)]];
  } else if (numLikes > 0) {
//    [badgeImages addObject:[UIImage imageNamed:@"Assets/Icons/LikesReadIcon"]];
//    [badgeColors addObject:[UIColor whiteColor]];
//    [badgeSizes addObject:[NSValue valueWithCGSize:CGSizeMake(13.0, 13.0)]];
  }
  
  self.badgeView.badgeImages = badgeImages;
  self.badgeView.badgeSizes = badgeSizes;
  self.badgeView.badgeColors = badgeColors;
}

@end
