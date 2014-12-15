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

- (void)setNumLikes:(NSUInteger)numLikes numComments:(NSUInteger)numComments
{
  if (numLikes == 0 && numComments == 0) {
    self.badgeLabel.text = nil;
    return;
  }
  
  NSString *markup = [NSString stringWithFormat:@"<photoBadge>%@#likes%@#comments</photoBadge>",
                      numLikes > 0 ? @(numLikes) : @"",
                      numComments > 0 ? @(numComments) : @""];
  NSError *error;
  NSMutableAttributedString *attributedsString = [[SLSMarkupParser
                                           attributedStringWithMarkup:markup
                                           style:[DFStrandConstants defaultTextStyle]
                                           error:&error] mutableCopy];
  NSRange likesRange = [attributedsString.string rangeOfString:@"#likes"];
  if (numLikes > 0) {
    
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    attachment.bounds = CGRectMake(0, -4, 13.0, 13.0);
     attachment.image = [[UIImage imageNamed:@"Assets/Icons/LikersListIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [attributedsString replaceCharactersInRange:likesRange
                           withAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
  } else {
    [attributedsString replaceCharactersInRange:likesRange
                                     withString:@""];

  }
  
  NSRange commentsRange = [attributedsString.string rangeOfString:@"#comments"];
  if (numComments > 0) {
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    attachment.bounds = CGRectMake(0, -4, 13.0, 13.0);
    attachment.image = [[UIImage imageNamed:@"Assets/Icons/CommentersListIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [attributedsString replaceCharactersInRange:commentsRange
                           withAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
  } else {
    [attributedsString replaceCharactersInRange:commentsRange withString:@""];
  }

  
  self.badgeLabel.attributedText = attributedsString;
}

@end
