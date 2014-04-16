//
//  DFUploadSessionStats.m
//  Duffy
//
//  Created by Henry Bridge on 3/20/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadSessionStats.h"

@implementation DFUploadSessionStats

@synthesize fatalError, numConsecutiveRetries, numTotalRetries;

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.uploadedURLs = [[NSMutableSet alloc] init];
        self.acceptedURLs = [[NSMutableSet alloc] init];
    }
    return self;
}


- (NSUInteger)numUploaded {
    return self.uploadedURLs.count;
}

- (NSUInteger)numAcceptedUploads {
    return self.acceptedURLs.count;
}

- (NSUInteger)numRemaining {
    return self.numAcceptedUploads - self.numUploaded;
}

- (float)progress
{
    return (float)self.numUploaded/(float)self.numAcceptedUploads;
}

@end
