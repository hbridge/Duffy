//
//  DFUploadSessionStats.m
//  Duffy
//
//  Created by Henry Bridge on 3/20/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFUploadSessionStats.h"

@implementation DFUploadSessionStats

@synthesize numThumbnailsAccepted, numThumbnailsUploaded, numFullPhotosAccepted, numFullPhotosUploaded, fatalError, numConsecutiveRetries, numTotalRetries, startDate, endDate, numBytesUploaded;

- (instancetype)init
{
    self = [super init];
    if (self) {
            }
    return self;
}

- (NSUInteger)numThumbnailsRemaining {
    return self.numThumbnailsAccepted - self.numThumbnailsUploaded;
}

- (NSUInteger)numFullPhotosRemaining {
    return self.numFullPhotosAccepted - self.numFullPhotosUploaded;
}

- (float)thumbnailProgress
{
    return (float)self.numThumbnailsUploaded/(float)self.numThumbnailsAccepted;
}

- (float)fullPhotosProgress
{
    return (float)self.numFullPhotosUploaded/(float)self.numFullPhotosAccepted;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"SessionStats: timeSinceStarted:%.02fs thumbs_accepted:%lu thumbs_uploaded:%lu thumbs_remaining:%lu full_accepted:%lu full_uploaded:%lu full_remaining:%lu consecutive_retries:%d total_retries:%d MBUploaded:%.02f throughputKBPS:%.02f",
            [[NSDate date] timeIntervalSinceDate:startDate],
            (unsigned long)self.numThumbnailsAccepted,
            (unsigned long)self.numThumbnailsUploaded,
            (unsigned long)self.numThumbnailsRemaining,
            (unsigned long)self.numFullPhotosAccepted,
            (unsigned long)self.numFullPhotosUploaded,
            (unsigned long)self.numFullPhotosRemaining,
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
