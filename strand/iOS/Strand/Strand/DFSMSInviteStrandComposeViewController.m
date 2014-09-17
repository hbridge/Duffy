//
//  DFSMSInviteStrandComposeViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSMSInviteStrandComposeViewController.h"

@interface DFSMSInviteStrandComposeViewController ()

@end

@implementation DFSMSInviteStrandComposeViewController

#if BETA
static NSString *const appURL = @"http://bit.ly/strand-beta";
#else
static NSString *const appURL = @"http://bit.ly/strand-appstore";
#endif

- (instancetype)initWithRecipients:(NSArray *)recipients
{
  self = [super init];
  if (self) {
    self.recipients = recipients;
    self.body = [NSString stringWithFormat:@"I've sent you photos with Strand. "
                 "Download the app here to see them and share yours: %@",
                 appURL];
  }
  return self;
}


- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissViewControllerAnimated:YES completion:nil];
}


@end
