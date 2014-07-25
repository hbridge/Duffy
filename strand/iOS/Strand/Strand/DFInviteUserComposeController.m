//
//  DFInviteUserComposeControllerViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInviteUserComposeController.h"
#import "DFPeanutInviteMessageAdapter.h"
#import "DFAnalytics.h"

@interface DFInviteUserComposeController ()

@property (nonatomic, retain) DFPeanutInviteMessageResponse *loadedResponse;
@property (nonatomic, retain) DFPeanutInviteMessageAdapter *inviteAdapter;
@property (atomic) BOOL isLoadMessageInProgress;

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
  if (self.isBeingPresented) {
    messageLoadCompletion([NSError
                           errorWithDomain:@"com.duffyapp.Strand"
                           code:-11
                           userInfo:@{
                                      NSLocalizedDescriptionKey: @"Trying to load message when "
                                      "invite controller already being presented."
                                      }]);
    return;
  }
  
  [self.inviteAdapter fetchInviteMessageResponse:^(DFPeanutInviteMessageResponse *response, NSError *error) {
    if (!error) {
      self.loadedResponse = response;
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
  DDLogInfo(@"%@ finishedw with result: %d", [self.class description], result);
  [DFAnalytics logInviteComposeFinishedWithResult:result
                         presentingViewController:self.presentingViewController];
  [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
           NSString *message = [NSString stringWithFormat:@"You have %d invites remaining.",
                             self.loadedResponse.invites_remaining];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Remaining Invites"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles: nil];
        [alert show];
  }];
  
}


- (void)viewDidLoad
{
  [super viewDidLoad];
  // Do any additional setup after loading the view.
}


- (DFPeanutInviteMessageAdapter *)inviteAdapter
{
  if (!_inviteAdapter) {
    _inviteAdapter = [[DFPeanutInviteMessageAdapter alloc] init];
  }
  
  return _inviteAdapter;
}

@end
