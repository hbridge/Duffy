//
//  DFInviteUserViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInviteUserViewController.h"
#import "DFInviteUserComposeController.h"
#import "UIAlertView+DFHelpers.h"
#import "DFUserPeanutAdapter.h"

@interface DFInviteUserViewController ()

@property (nonatomic, retain) DFInviteUserComposeController *composeController;
@property (readonly, nonatomic, retain) DFUserPeanutAdapter *userAdapter;
@property (nonatomic, retain) DFPeanutUserObject *peanutUser;

@end

@implementation DFInviteUserViewController

@synthesize userAdapter = _userAdapter;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
      self.composeController = [[DFInviteUserComposeController alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  if (self.composeController.isBeingDismissed) {
    // we're coming back form the child compose controller
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (!self.composeController || self.composeController.isBeingDismissed) {
    // the the view controller failed to load
    [self dismissViewControllerAnimated:YES completion:nil];
  } else {
    [self.userAdapter getCurrentUserWithSuccess:^(DFPeanutUserObject *user) {
      self.peanutUser = user;
      if (user.invites_remaining.intValue > 0) {
        [self showComposer];
      } else {
        [self dismissViewControllerAnimated:YES completion:^{
          [UIAlertView showSimpleAlertWithTitle:@"No Invites Remaining"
                                        message:@"You have no invites remaining."];
          
        }];
      }
    } failure:^(NSError *error) {
      [self dismissViewControllerAnimated:YES completion:^{
        [UIAlertView showSimpleAlertWithTitle:@"Error"
                                      message:[NSString stringWithFormat:
                                               @"Could determine how many remaining invites you have. %@",
                                               error.localizedDescription]];
        
      }];
    }];
  }
}

- (void)showComposer
{
  [self.composeController loadMessageWithCompletion:^(NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (!error) {
        [self presentViewController:self.composeController animated:YES completion:nil];
      } else {
        [UIAlertView showSimpleAlertWithTitle:@"Error" message:error.localizedDescription];
        [self dismissViewControllerAnimated:YES completion:nil];
      }
    });
  }];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
  if (self.composeController.result == MessageComposeResultSent) {
    self.peanutUser.invites_remaining = @(self.peanutUser.invites_remaining.intValue - 1);
    self.peanutUser.invites_sent = @(self.peanutUser.invites_sent.intValue + 1);
    [self.userAdapter
     performRequest:RKRequestMethodPUT
     withPeanutUser:self.peanutUser
     success:^(DFPeanutUserObject *user) {
       [UIAlertView showSimpleAlertWithTitle:@"Invite Sent"
                               formatMessage:@"You have %d invites remaining.",
        self.peanutUser.invites_remaining.intValue];
     } failure:^(NSError *error) {
       DDLogError(@"%@ put of user object %@ failed with error: %@",
                  [self.class description],
                  self.peanutUser,
                  error.description);
     }];
  }
  
  [self.presentingViewController dismissViewControllerAnimated:flag completion:completion];
}

- (DFUserPeanutAdapter *)userAdapter
{
  if (!_userAdapter) _userAdapter = [[DFUserPeanutAdapter alloc] init];
  return _userAdapter;
}

@end
