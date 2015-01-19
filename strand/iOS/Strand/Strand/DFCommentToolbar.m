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
  [self configureButtonImages];
  
  self.textField.tintColor = [UIColor lightGrayColor];
  [self.textField addTarget:self
                     action:@selector(editingStartedStopped:)
           forControlEvents:UIControlEventEditingDidBegin | UIControlEventEditingDidEnd];
  [self.textField addTarget:self
                     action:@selector(textChanged:)
           forControlEvents:UIControlEventEditingChanged];
  [self textChanged:self.textField];
  self.textField.delegate = self;
}

- (void)configureButtonImages
{
  [self.likeButton setImage:[UIImage imageNamed:@"Assets/Icons/LikeButtonIcon"]
                   forState:UIControlStateNormal];
  [self.commentButton setImage:[UIImage imageNamed:@"Assets/Icons/CommentButtonIcon"]
                   forState:UIControlStateNormal];
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
  if (!button) return;
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

- (NSArray *)nonCommentButtons
{
  return @[self.likeButton, self.commentButton, self.moreButton];
}

- (void)setCommentFieldHidden:(BOOL)commentFieldHidden
{
  for (UIView *nonCommentView in [self nonCommentButtons]) {
    nonCommentView.hidden = !commentFieldHidden;
  }
  for (UIView *view in @[self.textField, self.sendButton]) {
    view.hidden = commentFieldHidden;
  }
}

- (void)setLikeBarButtonItemOn:(BOOL)on
{
  if (on) {
    [self.likeButton setImage:[UIImage imageNamed:@"Assets/Icons/LikeOnButtonIcon"] forState:UIControlStateNormal];
    [self.likeButton setTitle:@"Liked" forState:UIControlStateNormal];
  } else {
    [self.likeButton setImage:[UIImage imageNamed:@"Assets/Icons/LikeOffButtonIcon"] forState:UIControlStateNormal];
    [self.likeButton setTitle:@"Like" forState:UIControlStateNormal];
  }
}

- (IBAction)likeButtonPressed:(id)sender {
  if (self.likeHandler) self.likeHandler();
}

- (IBAction)commentButtonPressed:(id)sender {
  [self setCommentFieldHidden:NO];
  [self.textField becomeFirstResponder];
}

- (void)editingStartedStopped:(UITextField *)sender
{
  [self textChanged:sender];
  if (!sender.isFirstResponder) [self setCommentFieldHidden:YES];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [self sendButtonPressed:self.textField];
  return NO;
}

- (void)textChanged:(UITextField *)sender
{
  if (sender.text.length > 0) {
    self.sendButton.enabled = YES;
  } else {
    self.sendButton.enabled = NO;
  }
}


- (IBAction)sendButtonPressed:(id)sender {
  if (self.sendBlock) self.sendBlock(self.textField.text);
  [self textChanged:self.textField];
}

- (IBAction)moreButtonPressed:(id)sender {
  if (self.moreHandler) self.moreHandler();
}

@end
