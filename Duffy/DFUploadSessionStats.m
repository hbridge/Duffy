//
//  DFUploadSessionStats.m
//  Duffy
//
//  Created by Henry Bridge on 3/20/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadSessionStats.h"

@implementation DFUploadSessionStats

@synthesize numAcceptedUploads, numUploaded, fatalError, numConsecutiveRetries, numTotalRetries, startDate, endDate, numBytesUploaded;

- (instancetype)init
{
    self = [super init];
    if (self) {
            }
    return self;
}

- (NSUInteger)numRemaining {
    return self.numAcceptedUploads - self.numUploaded;
}

- (float)progress
{
    return (float)self.numUploaded/(float)self.numAcceptedUploads;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"SessionStats: timeSinceStarted:%.02fs accepted:%lu uploaded:%lu remaining:%lu consecutive_retries:%d total_retries:%d MBUploaded:%.02f throughputKBPS:%.02f",
            [[NSDate date] timeIntervalSinceDate:startDate],
            (unsigned long)self.numAcceptedUploads,
            (unsigned long)self.numUploaded,
            (unsigned long)self.numRemaining,
            self.numConsecutiveRetries,
            self.numTotalRetries,
            (double)self.numBytesUploaded/1024.0/1024.0,
            self.throughPutKBPS];
}


- (double)throughPutKBPS
{
    NSDate *calcEndDate = self.endDate;
    if (!calcEndDate) calcEndDate = [NSDate date];
    
    unsigned long uploadedKB = self.numBytesUploaded/1024;
    NSTimeInterval seconds = [calcEndDate timeIntervalSinceDate:self.startDate];
    return uploadedKB/seconds;
}

@end
