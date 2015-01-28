//
//  DFNoIncomingViewController.m
//  Strand
//
//  Created by Derek Parham on 12/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUpsellCardViewController.h"
#import "DFAnalytics.h"


@implementation DFUpsellCardViewController

- (instancetype)initWithType:(DFUpsellCardViewType)upsellType
{
  self = [super init];
  if (self) {
    _upsellType = upsellType;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureSwipableButtonView];
  
  self.upsellContentView = [UINib instantiateViewWithClass:[DFUpsellContentView class]];
  self.upsellContentView.frame = CGRectMake(0, 0, self.swipableButtonView.centerView.frame.size.width, 24 * 3);
  
  self.upsellContentView.translatesAutoresizingMaskIntoConstraints = NO;
  
  self.upsellContentView.topLabel.font = [UIFont systemFontOfSize:24];
  self.upsellContentView.bottomLabel.font = [UIFont systemFontOfSize:17];

  [self.swipableButtonView configureToUseView:self.upsellContentView];
  
  [self configureUpsellContent];
}

- (void)configureUpsellContent
{
  if (self.upsellType == DFUpsellCardViewGotoSuggestions) {
    self.upsellContentView.topLabel.text = @"No More Photos To Review";
    self.upsellContentView.bottomLabel.text = @"Review Suggestions?";
  } else if (self.upsellType == DFUpsellCardViewBackgroundLocation) {
    self.upsellContentView.topLabel.text = @"Get More Suggestions";
    self.upsellContentView.bottomLabel.text = @"Grant location permission to get suggestions "
    "even when you don't take a photo";
    self.upsellContentView.imageView.image = [UIImage imageNamed:@"Assets/Nux/LocationAccessGraphic"];
  }
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
  
  NSString *typeString = @"unknown";
  if (self.upsellType == DFUpsellCardViewGotoSuggestions) {
    typeString = @"NoIncomingInterstitial";
  } else if (self.upsellType == DFUpsellCardViewBackgroundLocation) {
    typeString = @"BackgroundLocationUpsell";
  } else {
    #ifdef DEBUG
    [NSException raise:@"not logged properly" format:@"other card not logged properly"];
    #endif
  }
  [DFAnalytics logOtherCardType:typeString
            processedWithResult:result
                     actionType:isSwipe ? DFAnalyticsActionTypeSwipe : DFAnalyticsActionTypeTap];
}


- (void)configureSwipableButtonView
{
  [self.swipableButtonView configureWithShowsOther:NO];
  self.swipableButtonView.delegate = self;
  [self.swipableButtonView.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SwipeCheckButton"]
   forState:UIControlStateNormal];
  [self.swipableButtonView.yesButton setTitle:@"Yes" forState:UIControlStateNormal];
  [self.swipableButtonView.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SwipeXButton"]
   forState:UIControlStateNormal];
  [self.swipableButtonView.noButton setTitle:@"Not Now" forState:UIControlStateNormal];
}

@end
