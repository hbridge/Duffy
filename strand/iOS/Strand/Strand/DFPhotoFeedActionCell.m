//
//  DFPhotoFeedActionCell.m
//  Strand
//
//  Created by Henry Bridge on 11/19/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedActionCell.h"
#import <Slash/Slash.h>

@implementation DFPhotoFeedActionCell

- (void)awakeFromNib {
  [super awakeFromNib];
  self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if (self.actionLabel.preferredMaxLayoutWidth != self.actionLabel.frame.size.width) {
    self.actionLabel.preferredMaxLayoutWidth = self.actionLabel.frame.size.width;
    [self setNeedsLayout];
  }
}

- (void)setLikes:(NSArray *)likeActions
{
  self.iconImageView.image = [UIImage imageNamed:@"Assets/Icons/LikersListIcon"];
  NSMutableString *markup = [NSMutableString new];
  for (DFPeanutAction *action in likeActions) {
    [markup appendFormat:@"<name>%@</name>", action.firstNameOrYou];
    if (action != likeActions.lastObject) [markup appendString:@", "];
  }
  [self setLabelTextWithMarkup:markup];
}

- (void)setComment:(DFPeanutAction *)commentAction
{
  self.iconImageView.image = [UIImage imageNamed:@"Assets/Icons/CommentersListIcon"];
  NSMutableString *markup = [NSMutableString new];
  [markup appendString:@"<feedText>"];
  [markup appendFormat:@"<name>%@</name> %@",
   commentAction.firstNameOrYou,
   [commentAction.text stringByEscapingCharsInString:@"<>"]];
  
  [markup appendString:@"</feedText>"];
  [self setLabelTextWithMarkup:markup];
}

- (void)setLabelTextWithMarkup:(NSString *)markup
{
  NSError *error;
  NSAttributedString *actionString = [SLSMarkupParser attributedStringWithMarkup:markup
                                                                           style:[DFStrandConstants defaultTextStyle]
                                                                           error:&error];
  if (error) {
    DDLogError(@"%@ error parsing format:%@", self.class, error);
  }
  
  self.actionLabel.attributedText = actionString;
  [self setNeedsLayout];
}

- (CGFloat)rowHeight
{
  CGFloat height = [self.contentView
                    systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
  
  return height;
}


@end
