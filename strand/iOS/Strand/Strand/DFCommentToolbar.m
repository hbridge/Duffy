//
//  DFCommentToolbar.m
//  Strand
//
//  Created by Henry Bridge on 12/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCommentToolbar.h"

@implementation DFCommentToolbar

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.profileStackView.backgroundColor = [UIColor clearColor];
  self.sendButton = [[UIButton alloc] init];
  [self.sendButton setTitle:@"Send" forState:UIControlStateNormal];
  self.sendButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self.sendButton setTitleColor:[DFStrandConstants strandBlue] forState:UIControlStateNormal];
  [self.sendButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
  [self.textField addTarget:self
                     action:@selector(editingStartedStopped:)
           forControlEvents:UIControlEventEditingDidBegin | UIControlEventEditingDidEnd];
  [self.textField addTarget:self
                     action:@selector(textChanged:)
           forControlEvents:UIControlEventEditingChanged];
  [self textChanged:self.textField];
}

- (id)awakeAfterUsingCoder:(NSCoder *)aDecoder
{
  if (self.subviews.count == 0) {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIView *view = (UIView *)[[bundle loadNibNamed:NSStringFromClass(self.class)
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

- (void)addRightButtonToView:(UIButton *)button
{
  [self addSubview:button];
  [self addConstraints:[NSLayoutConstraint
                        constraintsWithVisualFormat:@"[textfield]-(8)-[button]-(8)-|"
                        options:0
                        metrics:nil
                        views:@{
                                @"textfield" : self.textField,
                                @"button" : button
                                }]];
  [self addConstraint:[NSLayoutConstraint constraintWithItem:self.textField
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:button
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1.0
                                                    constant:0]];
  
  CGFloat width = (button == self.sendButton) ? 50.0 : 22.0;
  [self addConstraint:[NSLayoutConstraint constraintWithItem:button
                                                   attribute:NSLayoutAttributeWidth
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:nil
                                                   attribute:NSLayoutAttributeWidth
                                                  multiplier:1.0
                                                    constant:width]];
  
}

- (void)dealloc
{
  self.retainedLikeButton = nil;
}

- (void)setSendButtonHidden:(BOOL)sendIsHidden
{
  if (sendIsHidden) {
    [self.sendButton removeFromSuperview];
    if (!self.likeButtonDisabled) {
      [self addRightButtonToView:self.likeButton];
      self.retainedLikeButton = nil;
    }
  } else {
    self.retainedLikeButton = self.likeButton;
    [self.likeButton removeFromSuperview];
    [self addRightButtonToView:self.sendButton];
  }
}

- (void)editingStartedStopped:(UITextField *)sender
{
  
}

- (void)setLikeButtonDisabled:(BOOL)likeButtonDisabled
{
  if (likeButtonDisabled) [self.likeButton removeFromSuperview];
}

- (void)textChanged:(UITextField *)sender
{
  if (sender.text.length > 0) {
    self.sendButton.enabled = YES;
    [self setSendButtonHidden:NO];
  } else {
    self.sendButton.enabled = NO;
    [self setSendButtonHidden:YES];
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.profileStackView.profilePhotoWidth = self.profileStackView.frame.size.width;
}

@end
