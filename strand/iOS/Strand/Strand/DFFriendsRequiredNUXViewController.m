//
//  DFFriendsRequiredNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 3/2/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFFriendsRequiredNUXViewController.h"
#import "DFPeanutFeedDataManager.h"
#import "DFAnalytics.h"

@implementation DFFriendsRequiredNUXViewController

const int DFMinFriendsRequired = 3;

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.titleLabel.text = @"Invite More Friends";
  self.explanationLabel.text = [NSString stringWithFormat:@"You need at least %d registered friends to use Swap."
  " Please add or invite additional friends to continue."
  "\n\n"
  "If you've already invited friends, we'll send you a text when %d have joined.",
                                DFMinFriendsRequired,
                                DFMinFriendsRequired];
  [self.button addTarget:self
                  action:@selector(buttonPressed:)
        forControlEvents:UIControlEventTouchUpInside];
  
  // configure profile photos
  self.profileStackView.backgroundColor = [UIColor clearColor];
  NSMutableArray *friends = [[[[DFPeanutFeedDataManager sharedManager] friendsList] objectsPassingTestBlock:^BOOL(id input) {
    return [input hasAuthedPhone];
  }] mutableCopy];

  NSMutableArray *fakeFriends = [NSMutableArray new];
  for (NSUInteger i = friends.count; i < DFMinFriendsRequired; i++) {
    DFPeanutUserObject *anon = [[DFPeanutUserObject alloc] init];
    anon.display_name = [NSString stringWithFormat:@"? %d", (int)i];
    anon.id = NSUIntegerMax - i;
    [friends addObject:anon];
    [fakeFriends addObject:anon];
  }
  
  [self.profileStackView setPeanutUsers:friends];
  
  for (DFPeanutUserObject *fakeUser in fakeFriends) {
    [self.profileStackView setColor:[UIColor grayColor] forUser:fakeUser];
  }
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  NSArray *friends = [[DFPeanutFeedDataManager sharedManager] friendsList];
  NSArray *authedFriends = [friends objectsPassingTestBlock:^BOOL(id input) {
    return [input hasAuthedPhone];
  }];
  
  [DFAnalytics logViewController:self
          appearedWithParameters:@{
                                   @"authedFriends" : @(authedFriends.count),
                                   @"unauthedFriends" : @(friends.count - authedFriends.count),
                                   }];
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)buttonPressed:(id)sender
{
  [self.navigationController popViewControllerAnimated:YES];
}

@end
