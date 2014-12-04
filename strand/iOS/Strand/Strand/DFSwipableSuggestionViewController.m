//
//  DFSwipableSuggestionViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/3/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwipableSuggestionViewController.h"

@interface DFSwipableSuggestionViewController ()


@end



@implementation DFSwipableSuggestionViewController

- (void)viewDidLoad {
  self.imageView = self.cardinalImageView.imageView;
  
  // Need to set the imageView first since the parent needs it
  [super viewDidLoad];
  
  self.cardinalImageView.delegate = self;

  //self.profileStackView.backgroundColor = [UIColor clearColor];
  self.profileStackView.peanutUsers = self.suggestionFeedObject.actors;
  self.profileStackView.profilePhotoWidth = 50.0;
  self.profileStackView.shouldShowNameLabel = YES;
  self.profileStackView.backgroundColor = [UIColor clearColor];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated
{
  [self.cardinalImageView resetView];
}

- (void)cardinalImageView:(DFCardinalImageView *)cardinalImageView
        buttonSelected:(UIButton *)button
{
  if (button == self.cardinalImageView.yesButton && self.yesButtonHandler) self.yesButtonHandler();
  else if (button == self.cardinalImageView.noButton && self.noButtonHandler) self.noButtonHandler();
}

@end
