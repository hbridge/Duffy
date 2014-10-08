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
                        date:(NSDate *)date
{
  self = [super init];
  if (self) {
    self.recipients = recipients;
    
    NSString *fromString = locationString;
    
    self.body = [NSString stringWithFormat:@"Hey! Sent you photos from %@. "
                 "Try this new app to view them and easily swap your matching photos. %@",
                 fromString,
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
