
//
//  DFSuggestionContentView.m
//  Strand
//
//  Created by Henry Bridge on 12/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFOutgoingCardContentView.h"
#import <MMPopLabel/MMPopLabel.h>


@interface DFOutgoingCardContentView()

@property (nonatomic) MMPopLabel *selectPeoplePopLabel;

@end

@implementation DFOutgoingCardContentView

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self configurePopLabel];
  self.imageView.layer.cornerRadius = 4.0;
  self.imageView.layer.masksToBounds = YES;
  self.commentTextField.delegate = self;
  self.profileStackView.backgroundColor = [UIColor clearColor];
}

- (IBAction)addButtonPressed:(id)sender {
  [self.commentTextField resignFirstResponder];
  if (self.addHandler) self.addHandler();
}

- (id)awakeAfterUsingCoder:(NSCoder *)aDecoder
{
  if (self.subviews.count == 0) {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIView *view = [[bundle loadNibNamed:NSStringFromClass(self.class) owner:nil options:nil] firstObject];
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

- (void)configurePopLabel
{
  self.selectPeoplePopLabel = [MMPopLabel popLabelWithText:@"Add the people you were with"];
  [self addSubview:self.selectPeoplePopLabel];
}

- (void)showAddPeoplePopup
{
  [self.selectPeoplePopLabel popAtView:self.addButton animatePopLabel:YES animateTargetView:NO];
}

- (void)dismissAddPeoplePopup
{
  [self.selectPeoplePopLabel dismiss];
}

- (IBAction)contentViewTapped:(id)sender {
  [self.commentTextField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  [self.commentTextField resignFirstResponder];
  return YES;
}


@end
