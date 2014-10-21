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
    
    self.body = [NSString stringWithFormat:@"Hey! Sent you photos from %@. "
                 "Let's try this app to swap photos. %@",
                 fromString,
                 appURL];
  }
  return self;
}

- (NSString *)getDayOfTheWeek:(NSDate *)date{
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  
  dateFormatter.dateFormat = @"EEEE";
  NSString *formattedDateString = [dateFormatter stringFromDate:date];
  return formattedDateString;
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissViewControllerAnimated:YES completion:nil];
}


@end
