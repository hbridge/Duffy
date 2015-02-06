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
  
  self.view.backgroundColor = [UIColor clearColor];
  [self configureSwipableButtonView];
  self.upsellContentView.topLabel.font = [UIFont systemFontOfSize:24];
  self.upsellContentView.bottomLabel.font = [UIFont systemFontOfSize:17];

  [self configureUpsellContent];
}

- (void)configureUpsellContent
{
  if (self.upsellType == DFUpsellCardViewGotoSuggestions) {
    self.upsellContentView.topLabel.text = @"No More Photos To Review";
    self.upsellContentView.bottomLabel.text = @"Review Suggestions?";
  } else if (self.upsellType == DFUpsellCardViewBackgroundLocation) {
    self.upsellContentView.topLabel.text = @"Get More Photos";
    self.upsellContentView.bottomLabel.text = @"Grant location permission to get more photos from friends";
    self.upsellContentView.imageView.image = [UIImage imageNamed:@"Assets/Nux/LocationAccessGraphic"];
  }
}



- (void) buttonSelected:(UIButton *)button
{
  NSString *result;
  if (button == self.yesButton) {
    if (self.yesButtonHandler) self.yesButtonHandler();
    result = @"yes";
  } else if (button == self.noButton) {
    if (self.noButtonHandler) self.noButtonHandler();
    result = @"no";
  }
  
  [DFAnalytics logOtherCardType:[self typeString]
            processedWithResult:result
                     actionType:DFAnalyticsActionTypeTap];
}


- (void)configureSwipableButtonView
{
  [self.yesButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SwipeCheckButton"]
   forState:UIControlStateNormal];
  [self.yesButton setTitle:@"Yes" forState:UIControlStateNormal];
  [self.yesButton addTarget:self
                     action:@selector(buttonSelected:)
           forControlEvents:UIControlEventTouchUpInside];
  [self.noButton
   setImage:[UIImage imageNamed:@"Assets/Icons/SwipeXButton"]
   forState:UIControlStateNormal];
  [self.noButton setTitle:@"Not Now" forState:UIControlStateNormal];
  [self.noButton addTarget:self
                    action:@selector(buttonSelected:)
          forControlEvents:UIControlEventTouchUpInside];
}

- (NSString *)typeString
{
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
  return typeString;
}

@end
