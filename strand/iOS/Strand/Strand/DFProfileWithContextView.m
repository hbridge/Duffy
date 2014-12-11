//
//  DFProfileWithContextView.m
//  Strand
//
//  Created by Henry Bridge on 11/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFProfileWithContextView.h"
#import <Slash/Slash.h>

@implementation DFProfileWithContextView

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.profileStackView.backgroundColor = [UIColor clearColor];
  self.backgroundColor = [UIColor clearColor];
}

- (id)awakeAfterUsingCoder:(NSCoder *)aDecoder
{
  if (self.subviews.count == 0) {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIView *view = (DFProfileWithContextView *)[[bundle loadNibNamed:NSStringFromClass(self.class)
                                                               owner:nil
                                                             options:nil] firstObject];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *constraints = self.constraints;
    for (NSLayoutConstraint *constraint in constraints) {
      id firstItem = constraint.firstItem == self ? view : constraint.firstItem;
      id secondItem = constraint.secondItem == self ? view : constraint.secondItem;
      NSLayoutConstraint *newConstraint = [NSLayoutConstraint
                                           constraintWithItem:firstItem
                                           attribute:constraint.firstAttribute
                                           relatedBy:constraint.relation
                                           toItem:secondItem attribute:constraint.secondAttribute multiplier:constraint.multiplier constant:constraint.constant];
      [self removeConstraint:constraint];
      
      [view addConstraint:newConstraint];
    }
    return view;
  }
  
  return self;
}

- (void)setTitle:(NSString *)title
{
  self.titleLabel.text = title;
  [self setNeedsLayout];
}

- (NSString *)title
{
  return self.titleLabel.text;
}

- (void)setSubTitle:(NSString *)subTitle
{
  self.subtitleLabel.text = subTitle;
  [self setNeedsLayout];
}

- (NSString *)subTitle
{
  return self.subtitleLabel.text;
}

- (void)setTitleMarkup:(NSString *)titleMarkup
{
  NSError *error;
  self.titleLabel.attributedText = [SLSMarkupParser
                                    attributedStringWithMarkup:titleMarkup
                                    style:[DFStrandConstants defaultTextStyle]
                                    error:&error];
  if (error) {
    DDLogError(@"%@ setTitleMarkupError:%@", self.class,error);
  }
}

@end
