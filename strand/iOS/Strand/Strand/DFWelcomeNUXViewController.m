//
//  DFWelcomeNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/28/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFWelcomeNUXViewController.h"
#import "DFAnalytics.h"

@interface DFWelcomeNUXViewController ()

@end

@implementation DFWelcomeNUXViewController

- (instancetype)init
{
  self = [super initWithTitle:@"Welcome to Swap"
                        image:[UIImage imageNamed:@"Assets/Nux/WelcomeGraphic"]
              explanationText:@"Swap is a fast and fun way to share photos with groups of friends."
                  buttonTitle:@"Get Started"];
  if (self) {
    
  }
  return self;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}


- (BOOL)prefersStatusBarHidden
{
  return YES;
}

@end
