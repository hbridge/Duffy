//
//  DFUploadSessionStats.m
//  Duffy
//
//  Created by Henry Bridge on 3/20/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadSessionStats.h"
#import "NSDictionary+DFJSON.h"

@implementation DFUploadSessionStats

@synthesize
    fatalError, numConsecutiveRetries, numTotalRetries,
    startDate, endDate, numBytesUploaded;

- (instancetype)init
{
    self = [super init];
    if (self) {
            }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"SessionStats: timeSinceStarted:%.02fs consecutive_retries:%d total_retries:%d MBUploaded:%.02f throughputKBPS:%.02f queues:%@",
            [[NSDate date] timeIntervalSinceDate:startDate],
            self.numConsecutiveRetries,
            self.numTotalRetries,
            (double)self.numBytesUploaded/1024.0/1024.0,
            self.throughPutKBPS,
            self.queues];
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
