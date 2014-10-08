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
                    locationString:(NSString *)locationString
                        dateString:(NSString *)dateString
{
  self = [super init];
  if (self) {
    self.recipients = recipients;
    self.body = [NSString stringWithFormat:@"Hey! Photos from %@ here %@. "
                 "You'll have to register, but the app will make it easy to send your phots back.",
                 locationString, appURL];
  }
  return self;
}


- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissViewControllerAnimated:YES completion:nil];
}


@end
