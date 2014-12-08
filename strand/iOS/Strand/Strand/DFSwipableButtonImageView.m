
//
//  DFswipableButtonImageView.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwipableButtonImageView.h"
#import "DFSpringAttachmentBehavior.h"


const CGFloat UpGestureThreshold   = -75.0;
const CGFloat DownGestureThreshold = 75.0;
const CGFloat LeftGestureThreshold = -75.0;
const CGFloat RightGestureThreshold = 75.0;

@interface DFSwipableButtonImageView()

@property (nonatomic, retain) UIDynamicAnimator *animator;
@property (nonatomic, retain) DFSpringAttachmentBehavior *springBehavior;
@property (nonatomic) CGPoint originalCenter;
@property (nonatomic) CGPoint lastPoint;
@property (nonatomic) CGFloat lastVelocity;


@end

@implementation DFSwipableButtonImageView

//- (instancetype)initWithFrame:(CGRect)frame
//{
//  self = [super initWithFrame:frame];
//  if (self)
//    [self setupNib];
//  return self;
//}

//- (instancetype)initWithCoder:(NSCoder *)aDecoder
//{
//  self = [super initWithCoder:aDecoder];
//  if (self)
//    [self setupNib];
//  return self;
//}

//- (void)setupNib
//{
//  UIView *view = [self loadNib];
//  view.frame = self.bounds;
//  view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//  [self addSubview:view];
//}
//
//- (UIView *)loadNib
//{
//  return [UINib instantiateViewWithClass:[self class]];
//}

- (void)awakeFromNib
{
  [super awakeFromNib];
  _yesEnabled = YES;
  _noEnabled = YES;
  self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
  self.originalCenter = self.imageView.center;
  self.imageView.layer.cornerRadius = 3.0;
  self.imageView.layer.masksToBounds = YES;
  
  for (UIButton *button in @[self.noButton, self.otherButton, self.yesButton]) {
    button.layer.cornerRadius = button.frame.size.height / 2.0;
    button.layer.masksToBounds = YES;
  }
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
  self.imageView.center = self.originalCenter;
  self.imageView.alpha = 1.0;
  [self unhighlightAllButtons];
}

- (void)setYesEnabled:(BOOL)yesEnabled
{
  _yesEnabled = yesEnabled;
  self.yesButton.enabled = yesEnabled;
}

- (void)setNoEnabled:(BOOL)noEnabled
{
  _noEnabled = noEnabled;
  self.noButton.enabled = noEnabled;
}





#pragma mark - Drag Handling


- (IBAction)panGestureChanged:(UIPanGestureRecognizer *)recognizer {
  CGPoint translation = [recognizer translationInView:self.superview];
  if (recognizer.state == UIGestureRecognizerStateBegan) {
    [self handleDragBegan:translation];
  }
  [self handleDragMoved:translation];
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    [self handleDragEnded:translation];
  }
}

- (void)handleDragBegan:(CGPoint)translation
{
  if (self.springBehavior) {
    [self.animator removeBehavior:self.springBehavior];
    self.springBehavior = nil;
  }
  self.lastPoint = translation;
  
  if ([self.delegate respondsToSelector:@selector(swipableButtonImageView:didBeginPan:translation:)])
    [self.delegate swipableButtonImageView:self didBeginPan:self.panGestureRecognizer translation:translation];
}

- (void)handleDragMoved:(CGPoint)translation
{
  // move the image view to the dragged point
  CGRect frame = self.imageView.frame;
  frame.origin.x = frame.origin.x - (self.lastPoint.x - translation.x);
  frame.origin.y = frame.origin.y - (self.lastPoint.y - translation.y);
  [self setImageViewFrames:frame];
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
  
  if ([self.delegate respondsToSelector:@selector(swipableButtonImageView:didMovePan:translation:)])
    [self.delegate swipableButtonImageView:self didMovePan:self.panGestureRecognizer translation:translation];
}

- (void)handleDragEnded:(CGPoint)translation
{
  DDLogVerbose(@"finishing point y:%.02f", translation.y);
  if (translation.x < LeftGestureThreshold && self.noEnabled) {
    //left
    [self handleButtonSelected:self.noButton];
    return;
  } else if (translation.x > RightGestureThreshold && self.yesEnabled){
    [self handleButtonSelected:self.yesButton];
    return;
  }
    
  self.springBehavior = [[DFSpringAttachmentBehavior alloc]
                         initWithAnchorPoint:self.originalCenter attachedView:self.imageView];
  [self.animator addBehavior:self.springBehavior];
  [self unhighlightAllButtons];
  
  if ([self.delegate respondsToSelector:@selector(swipableButtonImageView:didEndPan:translation:)])
    [self.delegate swipableButtonImageView:self didEndPan:self.panGestureRecognizer translation:translation];
}

- (void)unhighlightAllButtons
{
  NSArray *buttons = @[self.yesButton, self.noButton];
  
  self.overlayImageView.alpha = 0.0;
  for (UIButton *button in buttons) {
    button.alpha = 1.0;
  }
}

- (void)highlightButton:(UIButton *)buttonToHighlight amount:(CGFloat)highlightAmount
{
  NSArray *buttons = @[self.yesButton, self.noButton];
  if (self.otherButton) buttons = [buttons arrayByAddingObject:self.otherButton];
  
  for (UIButton *button in buttons) {
    if (button == buttonToHighlight) {
      button.alpha = 0.2 + 0.8 * highlightAmount;
      self.overlayImageView.alpha = 0.2 + 0.8 * highlightAmount;
      //self.overlayImageView.image  = button.imageView.image;
    } else {
      button.alpha = 0.2;
    }
  }
}

- (void)setImageViewFrames:(CGRect)frame
{
  NSArray *imageViews = @[self.imageView, self.overlayImageView];
  for (UIView *view in imageViews) {
    view.frame = frame;
  }
}

#pragma mark - Selection Handlers

- (void)handleButtonSelected:(UIButton *)button
{
  CGRect destFrame = self.imageView.frame;
  if (button == self.noButton) {
    destFrame.origin.x = self.superview.frame.origin.x - destFrame.size.width;
  } else {
    destFrame.origin.x = CGRectGetMaxX(self.superview.frame) + destFrame.size.width;
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
  
  [UIView animateWithDuration:0.5
                        delay:0
       usingSpringWithDamping:2.0
        initialSpringVelocity:self.lastVelocity
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     self.imageView.frame = destFrame;
                     self.imageView.alpha = 0.0;
                   } completion:^(BOOL finished) {
                     [self.delegate swipableButtonImageView:self buttonSelected:button];
                   }];
}

- (void)animateImageViewToButton:(UIButton *)button
{

}

- (IBAction)yesButtonPressed:(id)sender {
  [self handleButtonSelected:sender];
}
- (IBAction)noButtonPressed:(id)sender {
    [self handleButtonSelected:sender];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.originalCenter = self.imageView.center;
}

@end
