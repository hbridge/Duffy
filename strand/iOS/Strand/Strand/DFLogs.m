//
//  DFLogs.m
//  Strand
//
//  Created by Henry Bridge on 11/5/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLogs.h"
#import <CocoaLumberjack/DDFileLogger.h>

@implementation DFLogs

static const int MaxLogFiles = 10;


+ (NSData *)aggregatedLogData
{
  NSMutableData *errorLogData = [NSMutableData data];
  for (NSData *errorLogFileData in [self errorLogData]) {
    [errorLogData appendData:errorLogFileData];
  }
  return errorLogData;
}

+ (NSMutableArray *)errorLogData
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
