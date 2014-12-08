//
//  DFSwapUpsellView.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapUpsellView.h"
#import "DFPeanutFeedDataManager.h"

@implementation DFSwapUpsellView

CGFloat const DFUpsellMinHeight = 200.0;

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.backgroundColor = [UIColor clearColor];
  self.gradientColors =
  @[
    [UIColor colorWithWhite:1.0 alpha:0.0],
    [UIColor colorWithWhite:1.0 alpha:0.8],
    [UIColor colorWithWhite:1.0 alpha:0.95],
    [UIColor colorWithWhite:1.0 alpha:0.98],
    ];
}


- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  if (CGRectContainsPoint(self.matchMyPhotosButton.frame, point)) {
    return YES;
  }
  return NO;
}

- (void)configureWithInviteObject:(DFPeanutFeedObject *)inviteObject
                     buttonTarget:(id)target
                         selector:(SEL)selector
{
  [self configureTextWithInviteObject:inviteObject];
  [self.matchMyPhotosButton setTitle:@"Find my Photos"
                            forState:UIControlStateNormal];

  [self.matchMyPhotosButton addTarget:target
                                action:selector
                      forControlEvents:UIControlEventTouchUpInside];
  self.activityWrapper.hidden = YES;
}

- (void)configureTextWithInviteObject:(DFPeanutFeedObject *)inviteObject
{
  DFPeanutFeedObject *strandPosts = [[inviteObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
  self.upsellTitleLabel.text = [NSString stringWithFormat:@"%@ %@ your photos from\n %@",
                                inviteObject.actorsString,
                                inviteObject.actors.count == 1 ? @"wants" : @"want",
                                strandPosts.placeAndRelativeTimeString];
}

- (void)reloadDataWithInviteObject:(DFPeanutFeedObject *)inviteObject
{
  [self configureTextWithInviteObject:inviteObject];
}

- (void)configureForContactsWithError:(BOOL)error
                         buttonTarget:(id)target
                                    selector:(SEL)selector
{
  self.gradientColors = @[
                          [[UIColor lightGrayColor] colorWithAlphaComponent:0],
                          [[UIColor lightGrayColor] colorWithAlphaComponent:0.8]
                          ];
  self.layer.borderColor = [[UIColor darkGrayColor] CGColor];
  if (!error) {
    self.upsellTitleLabel.text = @"Find Friends to Swap with";
  } else {
    self.upsellTitleLabel.text = @"Contacts Permission Denied";
  }
  [self.matchMyPhotosButton setTitle:@"Grant Contacts Access"
                            forState:UIControlStateNormal];
  [self.matchMyPhotosButton addTarget:target
                               action:selector
                     forControlEvents:UIControlEventTouchUpInside];
}

- (void)configureActivityWithVisibility:(BOOL)visible
{
  if (visible) {
    self.matchMyPhotosButton.hidden = YES;
    self.activityWrapper.hidden = NO;
  } else {
    self.matchMyPhotosButton.hidden = NO;
    self.activityWrapper.hidden = YES;
  }
}

- (BOOL)isMatchingActivityOn
{
  return !self.activityWrapper.hidden;
}

@end
