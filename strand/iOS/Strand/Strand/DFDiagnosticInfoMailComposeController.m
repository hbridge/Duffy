//
//  DFDiagnosticReporter.m
//  Duffy
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFDiagnosticInfoMailComposeController.h"
#import "DFAppInfo.h"
#import "DFLogs.h"

@implementation DFDiagnosticInfoMailComposeController

- (instancetype)initWithMailType:(DFMailType)mailType
{
  self = [super init];
  if (self) {
    if (mailType == DFMailTypeIssue) {
      NSData *errorLogData = [DFLogs aggregatedLogData];
      [self addAttachmentData:errorLogData mimeType:@"text/plain" fileName:@"StrandLog.txt"];
      [self setSubject:[NSString stringWithFormat:@"Issue report for %@", [DFAppInfo appInfoString]]];
      [self setToRecipients:[NSArray arrayWithObject:@"strand-support@duffytech.co"]];
    } else if (mailType == DFMailTypeFeedback) {
      [self setSubject:[NSString stringWithFormat:@"Feedback for %@", [DFAppInfo appInfoString]]];
      [self setToRecipients:[NSArray arrayWithObject:@"strand-feedback@duffytech.co"]];
    }
    
    self.mailComposeDelegate = self;
  }
  return self;
}



- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
  DDLogInfo(@"Diagnostic mail compose completed with result: %d", result);
  [self dismissViewControllerAnimated:YES completion:nil];
}


@end
