//
//  DFAddFriendsNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/27/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFAddFriendsNUXViewController.h"
#import "UIView+DFExtensions.h"

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

- (void)doneButtonPressed:(id)sender
{
  [self completedWithUserInfo:nil];
}



@end
