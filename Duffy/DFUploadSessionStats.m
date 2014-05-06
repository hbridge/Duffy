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

@synthesize numThumbnailsAccepted, numThumbnailsUploaded, numThumbnailsRemaining,
    numFullPhotosAccepted, numFullPhotosRemaining, numFullPhotosUploaded,
    fatalError, numConsecutiveRetries, numTotalRetries,
    startDate, endDate, numBytesUploaded;

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
    return [NSString stringWithFormat:@"SessionStats: timeSinceStarted:%.02fs consecutive_retries:%d total_retries:%d MBUploaded:%.02f throughputKBPS:%.02f \nthumbs_queue:\n%@ full_queue:\n%@",
            [[NSDate date] timeIntervalSinceDate:startDate],
            self.numConsecutiveRetries,
            self.numTotalRetries,
            (double)self.numBytesUploaded/1024.0/1024.0,
            self.throughPutKBPS,
            [@{
               @"accepted" : [NSNumber numberWithUnsignedInteger:self.numThumbnailsAccepted],
               @"remaining": [NSNumber numberWithUnsignedInteger:self.numThumbnailsRemaining],
               @"uploaded" : [NSNumber numberWithUnsignedInteger:self.numThumbnailsUploaded]
               } JSONStringPrettyPrinted:YES],
            [@{
               @"accepted" : [NSNumber numberWithUnsignedInteger:self.numFullPhotosAccepted],
               @"remaining": [NSNumber numberWithUnsignedInteger:self.numFullPhotosRemaining],
               @"uploaded" : [NSNumber numberWithUnsignedInteger:self.numFullPhotosUploaded]
               } JSONStringPrettyPrinted:YES]
            ];
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
