//
//  DFSMSInviteStrandComposeViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSMSInviteStrandComposeViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFAnalytics.h"
#import "DFContactSyncManager.h"
#import "DFPeanutContact.h"

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
    [DFAnalytics logInviteComposeInitialized];
  }
  return self;
}

- (instancetype)initWithRecipients:(NSArray *)recipients
{
  self = [super init];
  if (self) {
    self.recipients = recipients;
    self.body = [NSString stringWithFormat:@"Hey! Check out Swap app for sharing pics (still in private beta). %@", appURL];
    [DFAnalytics logInviteComposeInitialized];
  }
  return self;
}

- (instancetype)initForWarmup
{
  self = [super init];
  // do NOT log init
  return self;
}

+ (void)warmUpSMSComposer
{
  if (![MFMessageComposeViewController canSendText]) return;
  DFSMSInviteStrandComposeViewController *smsvc = [[DFSMSInviteStrandComposeViewController alloc] initForWarmup];
  [smsvc view]; //force the view controller's view to load, hopefully actually causes AB load etc
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
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
  DFSMSInviteStrandComposeViewController *smsvc = [[DFSMSInviteStrandComposeViewController alloc]
                                                   initWithRecipients:phoneNumbers
                                                   locationString:nil
                                                   date:date];
  [self showSMSVc:smsvc inParentViewController:parentViewController
     phoneNumbers:phoneNumbers
  completionBlock:completionBlock];
}

+ (void)showWithParentViewController:(UIViewController *)parentViewController
                        phoneNumbers:(NSArray *)phoneNumbers
                     completionBlock:(DFSMSComposeCompletionBlock)completionBlock
{
  DFSMSInviteStrandComposeViewController *smsvc = [[DFSMSInviteStrandComposeViewController alloc]
                                                   initWithRecipients:phoneNumbers];
  [self showSMSVc:smsvc
inParentViewController:parentViewController
     phoneNumbers:phoneNumbers
  completionBlock:completionBlock];
}

+ (void)showSMSVc:(DFSMSInviteStrandComposeViewController *)smsvc
inParentViewController:(UIViewController *)parentViewController
     phoneNumbers:(NSArray *)phoneNumbers
  completionBlock:(DFSMSComposeCompletionBlock)completionBlock
{
  [SVProgressHUD show];
  if (smsvc && [DFSMSInviteStrandComposeViewController canSendText]) {
    smsvc.completionBlock = completionBlock;
    smsvc.messageComposeDelegate = smsvc;
    dispatch_async(dispatch_get_main_queue(), ^{
      [parentViewController presentViewController:smsvc animated:YES completion:^{
        [SVProgressHUD dismiss];
      }];
    });
  } else {
    [SVProgressHUD showErrorWithStatus:@"Can't send text"];
    [DFAnalytics logInviteComposeFinishedWithResult:DFMessageComposeResultCouldntStart
                           presentingViewController:parentViewController];
    if (completionBlock) completionBlock(MessageComposeResultFailed);
  }
  
  NSArray *peanutContacts = [phoneNumbers arrayByMappingObjectsWithBlock:^id(id input) {
    DFPeanutContact *contact = [[DFPeanutContact alloc] init];
    contact.name = input;
    contact.phone_number = input;
    contact.user = @([[DFUser currentUser] userID]);
    return contact;
  }];
  
  [[DFContactSyncManager sharedManager] uploadInvitedContacts:peanutContacts];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [DFAnalytics logInviteComposeFinishedWithResult:result
                         presentingViewController:controller.presentingViewController];
  if (self.completionBlock) self.completionBlock(result);
  if (self.presentingViewController) {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

@end
