//
//  DFUploadSessionStats.h
//  Duffy
//
//  Created by Henry Bridge on 3/20/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFUploadQueue.h"

@interface DFUploadSessionStats : NSObject

@property (nonatomic, retain) NSDictionary *queues;

//errors and retries
@property (nonatomic, retain) NSError *fatalError;
@property (nonatomic) unsigned int numConsecutiveRetries;
@property (nonatomic) unsigned int numTotalRetries;

// time and throughput
@property (nonatomic, retain) NSDate *startDate;
@property (nonatomic, retain) NSDate *endDate;
@property (nonatomic) NSUInteger numBytesUploaded;
@property (nonatomic, readonly) double throughPutKBPS;

@end
