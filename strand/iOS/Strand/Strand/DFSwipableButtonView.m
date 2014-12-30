
//
//  DFswipableButtonView.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwipableButtonView.h"

const CGFloat UpGestureThreshold   = -75.0;
const CGFloat DownGestureThreshold = 75.0;
const CGFloat LeftGestureThreshold = -75.0;
const CGFloat RightGestureThreshold = 75.0;

@interface DFSwipableButtonView()

@property (nonatomic) CGPoint originalCenter;
@property (nonatomic) CGPoint lastPoint;
@property (nonatomic) CGFloat lastVelocity;


@end

@implementation DFSwipableButtonView


- (void)awakeFromNib
{
  [super awakeFromNib];
  _yesEnabled = YES;
  _noEnabled = YES;
  self.originalCenter = self.centerView.center;
  [self configureCenterViewLayer];
  
  for (UIButton *button in [self allButtons]) {
    button.layer.cornerRadius = button.frame.size.height / 2.0;
    button.layer.masksToBounds = YES;
  }
}

- (void)configureCenterViewLayer
{
  self.centerView.backgroundColor = [UIColor whiteColor];
  self.centerView.layer.cornerRadius = 3.0;
  self.centerView.layer.masksToBounds = NO;
  
  self.centerView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
  self.centerView.layer.borderWidth = 0.5;
  self.centerView.layer.shadowColor = [[UIColor colorWithWhite:0 alpha:0.3] CGColor];
  self.centerView.layer.shadowOffset = CGSizeMake(5, 5);
  self.centerView.layer.shadowOpacity = 0.5;

}

- (void)configureWithShowsOther:(BOOL)showsOther
{
  if (!showsOther) [self.otherButton removeFromSuperview];
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

- (void)resetView
{
  self.centerView.center = self.originalCenter;
  self.centerView.alpha = 1.0;
  [self unhighlightAllButtons];
}

- (void)setYesEnabled:(BOOL)yesEnabled
{
  _yesEnabled = yesEnabled;
  self.yesButton.enabled = yesEnabled;
  self.yesButton.alpha = yesEnabled ? 1.0 :0.2;
}

- (void)setNoEnabled:(BOOL)noEnabled
{
  _noEnabled = noEnabled;
  self.noButton.enabled = noEnabled;
  self.noButton.alpha = noEnabled ? 1.0 : 0.2;
}

#pragma mark - Drag Handling


- (IBAction)panGestureChanged:(UIPanGestureRecognizer *)recognizer {
  CGPoint translation = [recognizer translationInView:self.superview];
  if (recognizer.state == UIGestureRecognizerStateBegan) {
    [self handleDragBegan:translation];
  }
  [self handleDragMoved:translation];
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    [self handleDragEnded:translation sender:recognizer];
  }
}

- (void)handleDragBegan:(CGPoint)translation
{
  self.lastPoint = translation;
  
  if ([self.delegate respondsToSelector:@selector(swipableButtonView:didBeginPan:translation:)])
    [self.delegate swipableButtonView:self didBeginPan:self.panGestureRecognizer translation:translation];
}

- (void)handleDragMoved:(CGPoint)translation
{
  // move the image view to the dragged point
  CGRect frame = self.centerView.frame;
  frame.origin.x = frame.origin.x - (self.lastPoint.x - translation.x);
  frame.origin.y = frame.origin.y - (self.lastPoint.y - translation.y);
  [self setViewFrames:frame];
  self.lastVelocity = self.lastPoint.x - translation.x;
  self.lastPoint = translation;
  
  if (translation.x < 0) {
    //left
    CGFloat percentLeft = MIN(translation.x/LeftGestureThreshold, 1.0);
    [self highlightButton:self.noButton amount:percentLeft];
  } else {
    CGFloat percentRight = MIN(translation.x/RightGestureThreshold, 1.0);
    [self highlightButton:self.yesButton amount:percentRight];
  }
  
  if ([self.delegate respondsToSelector:@selector(swipableButtonView:didMovePan:translation:)])
    [self.delegate swipableButtonView:self didMovePan:self.panGestureRecognizer translation:translation];
}

- (void)handleDragEnded:(CGPoint)translation sender:(id)sender
{
  DDLogVerbose(@"finishing point y:%.02f", translation.y);
  if (translation.x < LeftGestureThreshold && self.noEnabled) {
    //left
    [self handleButtonSelected:self.noButton sender:sender];
    return;
  } else if (translation.x > RightGestureThreshold && self.yesEnabled){
    [self handleButtonSelected:self.yesButton sender:sender];
    return;
  }
  
  [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.3 initialSpringVelocity:self.lastVelocity options:UIViewAnimationOptionCurveEaseOut animations:^{
    self.centerView.center = self.originalCenter;
  } completion:^(BOOL finished) {
    
  }];
    
  [self unhighlightAllButtons];
  
  if ([self.delegate respondsToSelector:@selector(swipableButtonView:didEndPan:translation:)])
    [self.delegate swipableButtonView:self didEndPan:self.panGestureRecognizer translation:translation];
}

- (NSArray *)allButtons
{
  NSArray *buttons = @[self.yesButton, self.noButton];
  if (self.otherButton) buttons = [buttons arrayByAddingObject:self.otherButton];
  return buttons;
}

- (void)unhighlightAllButtons
{
  self.overlayImageView.alpha = 0.0;
  for (UIButton *button in [self allButtons]) {
    if (button.enabled) button.alpha = 1.0;
  }
}

- (void)highlightButton:(UIButton *)buttonToHighlight amount:(CGFloat)highlightAmount
{
  for (UIButton *button in [self allButtons]) {
    if (!button.enabled) continue;
    if (button == buttonToHighlight) {
      button.alpha = 0.2 + 0.8 * highlightAmount;
      self.overlayImageView.alpha = 0.2 + 0.8 * highlightAmount;
      //self.overlayImageView.image  = button.imageView.image;
    } else {
      button.alpha = 0.2;
    }
  }
}

- (void)setViewFrames:(CGRect)frame
{
  NSArray *views = @[self.centerView, self.overlayImageView];
  for (UIView *view in views) {
    view.frame = frame;
  }
}

#pragma mark - Selection Handlers

- (void)handleButtonSelected:(UIButton *)button sender:(id)sender
{
  BOOL animate = NO;
  CGRect destFrame = self.centerView.frame;
  if (button == self.noButton) {
    destFrame.origin.x = self.superview.frame.origin.x - destFrame.size.width;
    animate = YES;
  } else if (button == self.yesButton){
    destFrame.origin.x = CGRectGetMaxX(self.superview.frame) + destFrame.size.width;
    animate = YES;
  }
  
//  [UIView animateWithDuration:0.5
//                        delay:0
//                      options:UIViewAnimationOptionCurveEaseInOut
//                   animations:^{
//                     self.imageView.frame = destFrame;
//                     self.imageView.alpha = 0.0;
//                   } completion:^(BOOL finished) {
//                     [self.delegate swipableButtonImageView:self buttonSelected:button];
//                   }];
  BOOL isSwipe = [[sender class] isSubclassOfClass:[UIGestureRecognizer class]];
  if (animate) {
    [UIView animateWithDuration:0.5
                        delay:0
       usingSpringWithDamping:2.0
        initialSpringVelocity:self.lastVelocity
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     self.centerView.frame = destFrame;
                     self.centerView.alpha = 0.0;
                   } completion:^(BOOL finished) {
                     [self.delegate swipableButtonView:self
                                        buttonSelected:button
                                               isSwipe:isSwipe];
                   }];
  } else {
    [self.delegate swipableButtonView:self buttonSelected:button isSwipe:isSwipe];
  }
}

- (void)animateCenterViewToButton:(UIButton *)button
{

}
- (IBAction)commentButtonPressed:(id)sender {
  [self handleButtonSelected:sender sender:sender];
}

- (IBAction)yesButtonPressed:(id)sender {
//  self.yesButton.enabled = NO;
//  self.noButton.enabled = NO;
//  self.otherButton.enabled = NO;
  [self handleButtonSelected:sender sender:sender];
}
- (IBAction)noButtonPressed:(id)sender {
//  self.noButton.enabled = NO;
//  self.yesButton.enabled = NO;
//  self.otherButton.enabled = NO;
  [self handleButtonSelected:sender sender:sender];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.originalCenter = self.centerView.center;
}

- (void)setButtonsHidden:(BOOL)hidden
{
  self.buttonWrapperHeightConstraint.constant = (hidden ? 0 : 65.0);
}

/*
 * Configure this view to use an image.  This doesn't actually take in an image, that should be set later
 * on the .imageView property
 */
- (void)configureToUseImage
{
  self.imageView = [UIImageView new];
  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  
  self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.centerView addSubview:self.imageView];
  
  [self.centerView addConstraints:[NSLayoutConstraint
                                                      constraintsWithVisualFormat:@"|-(0)-[banner]-(0)-|"
                                                      options:0
                                                      metrics:nil
                                                      views:@{@"banner" : self.imageView}]];
  [self.centerView addConstraints:[NSLayoutConstraint
                                                      constraintsWithVisualFormat:@"V:|-(0)-[banner]-(0)-|"
                                                      options:0
                                                      metrics:nil
                                                      views:@{@"banner" : self.imageView}]];
}

/*
 * Configures this view to use a label in the center.  Access the label through the .labelView property
 */
- (void)configureToUseView:(UIView *)view
{
  for (UIView *subView in [self.centerView subviews]) {
    [subView removeFromSuperview];
  }
  [self.centerView addSubview:view];
  
  [self.centerView addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"|-(8)-[banner]-(8)-|"
                                   options:0
                                   metrics:nil
                                   views:@{@"banner" : view}]];
  [self.centerView addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-(8)-[banner]-(8)-|"
                                   options:0
                                   metrics:nil
                                   views:@{@"banner" : view}]];
}

@end
