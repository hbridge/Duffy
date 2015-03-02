//
//  DFFriendsRequiredNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 3/2/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFFriendsRequiredNUXViewController.h"
#import "DFPeanutFeedDataManager.h"

@implementation DFFriendsRequiredNUXViewController


- (void)viewDidLoad
{
  [super viewDidLoad];
  self.titleLabel.text = @"Invite More Friends";
  self.explanationLabel.text = @"You need at least 4 registered friends to use Swap."
  " Please add or invite additional friends to continue."
  "\n\n"
  "If you've already invited friends, we'll send you a text when 4 have joined.";
  [self.button addTarget:self
                  action:@selector(buttonPressed:)
        forControlEvents:UIControlEventTouchUpInside];
  
  // configure profile photos
  self.profileStackView.backgroundColor = [UIColor clearColor];
  NSMutableArray *friends = [[[[DFPeanutFeedDataManager sharedManager] friendsList] objectsPassingTestBlock:^BOOL(id input) {
    return [input hasAuthedPhone];
  }] mutableCopy];

  NSMutableArray *fakeFriends = [NSMutableArray new];
  for (NSUInteger i = friends.count; i < 4; i++) {
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

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)buttonPressed:(id)sender
{
  [self.navigationController popViewControllerAnimated:YES];
}

@end
