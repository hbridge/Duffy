//
//  DFDiagnosticReporter.m
//  Duffy
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFDiagnosticInfoMailComposeController.h"
#import <CocoaLumberjack/DDFileLogger.h>
#import "DFAppInfo.h"

@implementation DFDiagnosticInfoMailComposeController

static const int MaxLogFiles = 10;

- (instancetype)initWithMailType:(DFMailType)mailType
{
  self = [super init];
  if (self) {
    if (mailType == DFMailTypeIssue) {
      NSMutableData *errorLogData = [NSMutableData data];
      for (NSData *errorLogFileData in [self errorLogData]) {
        [errorLogData appendData:errorLogFileData];
      }
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

- (NSMutableArray *)errorLogData
{
  DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
  NSArray *sortedLogFileInfos = [[[fileLogger.logFileManager sortedLogFileInfos] reverseObjectEnumerator] allObjects];
  int numFilesToUpload = MIN((unsigned int)sortedLogFileInfos.count, MaxLogFiles);
  
  NSMutableArray *errorLogFiles = [NSMutableArray arrayWithCapacity:numFilesToUpload];
  for (int i = 0; i < numFilesToUpload; i++) {
    DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:i];
    NSData *fileData = [NSData dataWithContentsOfFile:logFileInfo.filePath];
    [errorLogFiles addObject:fileData];
  }
  
  return errorLogFiles;
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
  DDLogInfo(@"Diagnostic mail compose completed with result: %d", result);
  [self dismissViewControllerAnimated:YES completion:nil];
}


@end
