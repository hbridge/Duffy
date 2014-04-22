//
//  DFUploadSessionStats.m
//  Duffy
//
//  Created by Henry Bridge on 3/20/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadSessionStats.h"

@implementation DFUploadSessionStats

@synthesize numAcceptedUploads, numUploaded, fatalError, numConsecutiveRetries, numTotalRetries;

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
    return [NSString stringWithFormat:@"SessionStats: accepted:%lu uploaded:%lu remaining:%lu consecutive_retries:%d total_retries:%d",
            (unsigned long)self.numAcceptedUploads,
            (unsigned long)self.numUploaded,
            (unsigned long)self.numRemaining,
            self.numConsecutiveRetries,
            self.numTotalRetries];
}

@end
