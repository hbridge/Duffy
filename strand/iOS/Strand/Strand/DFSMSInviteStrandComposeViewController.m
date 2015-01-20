//
//  DFSMSInviteStrandComposeViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSMSInviteStrandComposeViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface DFSMSInviteStrandComposeViewController ()

@end

@implementation DFSMSInviteStrandComposeViewController

#if BETA
static NSString *const appURL = @"http://bit.ly/swap-beta";
#else
static NSString *const appURL = @"http://bit.ly/swap-appstore";
#endif

const NSTimeInterval DaysMultiplier = 60 * 60 * 24;

- (instancetype)initWithRecipients:(NSArray *)recipients
                    locationString:(NSString *)locationString
                        date:(NSDate *)date
{
  self = [super init];
  if (self) {
    self.recipients = recipients;
    
    NSUInteger daysSincePhotos = fabs(date.timeIntervalSinceNow / DaysMultiplier);
    NSString *fromString = locationString;
    if (daysSincePhotos == 0) {
      fromString = @"today";
    } else if (daysSincePhotos == 1) {
      fromString = @"yesterday";
    } else if (daysSincePhotos < 8) {
      fromString = [self getDayOfTheWeek:date];
    }
    if (fromString) fromString = [NSString stringWithFormat:@" from %@", fromString];
    
    self.body = [NSString stringWithFormat:@"Hey! Sent you a pic from %@. "
                 "Check out Swap app to see them. %@",
                 fromString ? fromString : @"",
                 appURL];
  }
  return self;
}

- (instancetype)initWithRecipients:(NSArray *)recipients
{
  self = [super init];
  if (self) {
    self.recipients = recipients;
    self.body = [NSString stringWithFormat:@"Hey! Check out Swap app for sharing pics (still in private beta). %@", appURL];
  }
  return self;
}

- (NSString *)getDayOfTheWeek:(NSDate *)date{
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  
  dateFormatter.dateFormat = @"EEEE";
  NSString *formattedDateString = [dateFormatter stringFromDate:date];
  return formattedDateString;
}

+ (void)showWithParentViewController:(UIViewController *)parentViewController
                        phoneNumbers:(NSArray *)phoneNumbers
                            fromDate:(NSDate *)date
                     completionBlock:(DFSMSComposeCompletionBlock)completionBlock
{
  [SVProgressHUD show];
  DFSMSInviteStrandComposeViewController *smsvc = [[DFSMSInviteStrandComposeViewController alloc]
                                                   initWithRecipients:phoneNumbers
                                                   locationString:nil
                                                   date:date];
  if (smsvc && [DFSMSInviteStrandComposeViewController canSendText]) {
    smsvc.messageComposeDelegate = smsvc;
    [parentViewController presentViewController:smsvc animated:YES completion:^{
      [SVProgressHUD dismiss];
    }];
  } else {
    [SVProgressHUD showErrorWithStatus:@"Can't send text"];
    if (completionBlock) completionBlock(MessageComposeResultFailed);
  }
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissViewControllerAnimated:YES completion:^{
    if (self.completionBlock) self.completionBlock(result);
  }];
}

@end
