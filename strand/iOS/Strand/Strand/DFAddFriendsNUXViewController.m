//
//  DFAddFriendsNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/27/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFAddFriendsNUXViewController.h"
#import "UIView+DFExtensions.h"
#import "DFPeanutFeedDataManager.h"
#import "DFFriendsRequiredNUXViewController.h"

@interface DFAddFriendsNUXViewController ()

@end

@implementation DFAddFriendsNUXViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self configureNav];
  
  self.inviteController = [[DFInviteFriendViewController alloc] init];
  self.inviteController.showExistingFriendsSection = YES;
  [self.view addSubview:self.inviteController.view];
  [self.inviteController.view constrainToSuperviewSize];
  [self addChildViewController:self.inviteController];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)configureNav
{
  self.navigationItem.title = @"Add Friends";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                            target:self
                                            action:@selector(doneButtonPressed:)];
}

const int MinFriendsRequired = 4;


- (void)doneButtonPressed:(id)sender
{
  // ensure the user has at least 4 friends before continuing
  NSArray *authedFriends = [[[DFPeanutFeedDataManager sharedManager] friendsList]
                            objectsPassingTestBlock:^BOOL(id input) {
                              return [input hasAuthedPhone];
                            }];
  
  if (authedFriends.count < MinFriendsRequired) {
    [self.navigationController pushViewController:[DFFriendsRequiredNUXViewController new] animated:YES];
  } else {
    [self completedWithUserInfo:nil];
  }
}

- (BOOL)prefersStatusBarHidden
{
  return [self.inviteController prefersStatusBarHidden];
}



@end
