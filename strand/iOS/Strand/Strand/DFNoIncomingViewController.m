//
//  DFNoIncomingViewController.m
//  Strand
//
//  Created by Derek Parham on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNoIncomingViewController.h"
#import "DFTwoLabelView.h"


@implementation DFNoIncomingViewController


- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureSwipableButtonView];
  
  DFTwoLabelView *view = [UINib instantiateViewWithClass:[DFTwoLabelView class]];
  CGRect frame = self.swipableButtonView.centerView.bounds;
  view.frame = frame;
  
  view.line1.text = @"No More Photos To Review";
  view.line2.text = @"Review Suggestions?";

  [self.swipableButtonView configureToUseView:view];
}



- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
            buttonSelected:(UIButton *)button
{
  if (button == self.swipableButtonView.yesButton) {
    if (self.yesButtonHandler) self.yesButtonHandler();
  } else if (button == self.swipableButtonView.noButton) {
    if (self.noButtonHandler) self.noButtonHandler();
  }
}


- (void)configureSwipableButtonView
{
  [self.swipableButtonView configureWithShowsOther:NO];
  self.swipableButtonView.delegate = self;
  [self.swipableButtonView.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SendButtonIcon"]
   forState:UIControlStateNormal];
  [self.swipableButtonView.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/IncomingSkipButtonIcon"]
   forState:UIControlStateNormal];
  for (UIButton *button in @[self.swipableButtonView.yesButton, self.swipableButtonView.noButton]) {
    [button setTitle:nil forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor];
  }
}

@end
