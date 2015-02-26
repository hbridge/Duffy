//
//  DFFindFriendsNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/27/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFFindFriendsNUXViewController.h"
#import "DFAlertController.h"
#import "DFContactSyncManager.h"
#import "DFContactDataManager.h"
#import "DFAnalytics.h"

@interface DFFindFriendsNUXViewController ()

@end

@implementation DFFindFriendsNUXViewController

- (instancetype)init
{
  self = [super initWithTitle:@"Find Friends"
                        image:[UIImage imageNamed:@"Assets/Nux/FriendsGraphic"]
              explanationText:@"Swap can suggest people to share photos with, but first you’ll need to find some friends on Swap."
                  buttonTitle:@"Next"];
  if (self) {
    
  }
  return self;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)buttonPressed:(id)sender
{
  [DFAnalytics logNux:@"Contacts" completedWithResult:@"Next"];
  [self completedWithUserInfo:nil];
}

@end
