//
//  DFInviteUserComposeControllerViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInviteUserComposeController.h"
#import "DFPeanutInviteMessageAdapter.h"

@interface DFInviteUserComposeController ()

@end

@implementation DFInviteUserComposeController

- (instancetype)init
{
  self = [super init];
  if (self) {
    self. messageComposeDelegate = self;
  }
  return self;
}

- (void)loadMessageWithCompletion:(void(^)(NSError *))messageLoadCompletion;
{
  DFPeanutInviteMessageAdapter *inviteAdapter = [[DFPeanutInviteMessageAdapter alloc] init];
  [inviteAdapter fetchInviteMessageResponse:^(DFPeanutInviteMessageResponse *response, NSError *error) {
    if (!error) {
      [self setBody:response.invite_message];
      
      // Present message view controller on screen
      messageLoadCompletion(nil);
    } else {
      messageLoadCompletion(error);
    }
  }];
}


- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissViewControllerAnimated:YES completion:^{
    DFPeanutInviteMessageAdapter *inviteAdapter = [[DFPeanutInviteMessageAdapter alloc] init];
    [inviteAdapter fetchInviteMessageResponse:^(DFPeanutInviteMessageResponse *response, NSError *error) {
      if (!error) {
        NSString *message = [NSString stringWithFormat:@"You have %d invites remaining.",
                             response.invites_remaining];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Remaining Invites"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles: nil];
        [alert show];
      }
    }];
  }];
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  // Do any additional setup after loading the view.
}


@end
