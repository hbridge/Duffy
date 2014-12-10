//
//  DFOverlayView.m
//  Strand
//
//  Created by Henry Bridge on 12/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFOverlayView.h"
#import "UIDevice+DFHelpers.h"

@interface DFOverlayView()

@property (nonatomic, retain) UIView *contentView;

@end

@implementation DFOverlayView

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.translatesAutoresizingMaskIntoConstraints =NO;
    [self configureBackground];
    [self addCloseButton];
    
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self configureBackground];
    [self addCloseButton];
  }
  return self;
}

- (void)configureBackground
{
  self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
}

- (void)addCloseButton
{
  self.closeButton = [[UIButton alloc] init];
  self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self.closeButton setTitle:nil forState:UIControlStateNormal];
  [self.closeButton setImage:[UIImage imageNamed:@"Assets/Icons/XIcon"]
                    forState:UIControlStateNormal];
  [self addSubview:self.closeButton];
  [self addConstraints:[NSLayoutConstraint
                        constraintsWithVisualFormat:@"V:|-(20)-[button]"
                        options:0
                        metrics:nil
                        views:@{@"button" : self.closeButton}]];
  [self addConstraints:[NSLayoutConstraint
                        constraintsWithVisualFormat:@"[button]-(5)-|"
                        options:0
                        metrics:nil
                        views:@{@"button" : self.closeButton}]];
  [self.closeButton addTarget:self action:@selector(closeButtonPressed:)
             forControlEvents:UIControlEventTouchUpInside];
}


- (void)setContentView:(UIView *)contentView
{
  if (self.contentView) [self.contentView removeFromSuperview];
  _contentView = contentView;
  [self insertSubview:contentView belowSubview:self.closeButton];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [self addConstraints:[NSLayoutConstraint
                        constraintsWithVisualFormat:@"V:|-(20)-[contentView]-(0)-|"
                        options:0
                        metrics:nil
                        views:@{@"button" : self.closeButton,
                                @"contentView" : contentView}]];
  [self addConstraints:[NSLayoutConstraint
                        constraintsWithVisualFormat:@"|-(0)-[contentView]-(0)-|"
                        options:0
                        metrics:nil
                        views:@{@"contentView" : contentView}]];
  
  
  // add a fancy background blur if iOS8 +
  if ([UIDevice majorVersionNumber] >= 8) {
    UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:
                                            
                                            [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    CGRect frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    visualEffectView.frame = frame;
    [self insertSubview:visualEffectView belowSubview:self.closeButton];
    [visualEffectView.contentView insertSubview:contentView belowSubview:self.closeButton];
    [visualEffectView.contentView addSubview:self.closeButton];
    
    
    //self.headerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
  }

}

- (void)closeButtonPressed:(UIButton *)sender
{
  if (self.closeButtonHandler) self.closeButtonHandler();
}

@end
