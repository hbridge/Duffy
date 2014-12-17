//
//  DFNoIncomingViewController.m
//  Strand
//
//  Created by Derek Parham on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNoIncomingViewController.h"
#import "DFTwoLabelView.h"
#import "DFAnalytics.h"


@implementation DFNoIncomingViewController


- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureSwipableButtonView];
  
  DFTwoLabelView *view = [UINib instantiateViewWithClass:[DFTwoLabelView class]];
  view.frame = self.swipableButtonView.centerView.bounds;
  
  view.topLabel.text = @"No More Photos To Review";
  view.bottomLabel.text = @"Review Suggestions?";
  
  view.bottomLabel.font = [UIFont systemFontOfSize:30];

  [self.swipableButtonView configureToUseView:view];
}



- (void)swipableButtonView:(DFSwipableButtonView *)swipableButtonView
            buttonSelected:(UIButton *)button
                   isSwipe:(BOOL)isSwipe
{
  NSString *result;
  if (button == self.swipableButtonView.yesButton) {
    if (self.yesButtonHandler) self.yesButtonHandler();
    result = @"yes";
  } else if (button == self.swipableButtonView.noButton) {
    if (self.noButtonHandler) self.noButtonHandler();
    result = @"no";
  }
  [DFAnalytics logOtherCardType:@"NoIncomingInterstitial"
            processedWithResult:result
                     actionType:isSwipe ? DFAnalyticsActionTypeSwipe : DFAnalyticsActionTypeTap];
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
