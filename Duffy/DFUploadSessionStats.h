//
//  DFUploadSessionStats.h
//  Duffy
//
//  Created by Henry Bridge on 3/20/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUploadSessionStats : NSObject

@property (atomic) NSMutableSet *uploadedURLs;
@property (atomic) NSMutableSet *acceptedURLs;


@property (nonatomic, readonly) NSUInteger numUploaded;
@property (nonatomic, readonly) NSUInteger numAcceptedUploads;
@property (nonatomic, readonly) NSUInteger numRemaining;
@property (nonatomic, readonly) float progress;

//errors and retries
@property (nonatomic, retain) NSError *fatalError;
@property (nonatomic) unsigned int numConsecutiveRetries;
@property (nonatomic) unsigned int numTotalRetries;

@end
