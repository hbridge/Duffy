//
//  DFFeedSectionHeaderView.m
//  Strand
//
//  Created by Henry Bridge on 7/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFeedSectionHeaderView.h"

@implementation DFFeedSectionHeaderView

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
  self.subtitleImageView.image = [UIImage imageNamed:@"Assets/Icons/LocationHeaderIcon"];
  self.subtitleImageView.contentMode = UIViewContentModeCenter;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (IBAction)inviteButtonPressed:(id)sender {
  if ([self.delegate respondsToSelector:@selector(inviteButtonPressedForHeaderView:)]) {
    [self.delegate inviteButtonPressedForHeaderView:self];
  }
}
@end
