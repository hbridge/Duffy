//
//  DFStrandPeopleBarView.m
//  Strand
//
//  Created by Henry Bridge on 10/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandPeopleBarView.h"

@implementation DFStrandPeopleBarView

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.backgroundColor = [DFStrandConstants defaultBackgroundColor];
}

- (void)configureWithStrandPostsObject:(DFPeanutFeedObject *)strandPostsObject
{
  self.peopleLabel.text = strandPostsObject.actorsString;
  NSString *invitedPeopleText = [strandPostsObject invitedActorsStringCondensed:NO];
  if ([invitedPeopleText isNotEmpty]) {
    self.invitedLabel.text = invitedPeopleText;
    self.peopleToInviteConstraint.priority = 999;
    self.invitedIcon.hidden = NO;
    self.invitedLabel.hidden = NO;
  } else {
    self.invitedIcon.hidden = YES;
    self.invitedLabel.hidden = YES;
    self.peopleToInviteConstraint.priority = 1;
  }

}


- (void)layoutSubviews
{
  [super layoutSubviews];
  DDLogVerbose(@"frame: %@", NSStringFromCGRect(self.frame));
}

@end
