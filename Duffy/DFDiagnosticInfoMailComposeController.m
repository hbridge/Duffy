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

- (instancetype)init
{
  self = [super init];
  if (self) {
    NSMutableData *errorLogData = [NSMutableData data];
    for (NSData *errorLogFileData in [self errorLogData]) {
      [errorLogData appendData:errorLogFileData];
    }
    [self addAttachmentData:errorLogData mimeType:@"text/plain" fileName:@"DuffyLog.txt"];
    [self setSubject:[NSString stringWithFormat:@"Diagnostic info for %@", [DFAppInfo appInfoString]]];
    [self setToRecipients:[NSArray arrayWithObject:@"hbridge@gmail.com"]];

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


@end
