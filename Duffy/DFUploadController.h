//
//  DFUploadController.h
//  Duffy
//
//  Created by Henry Bridge on 3/11/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFUploadSessionStats.h"

@interface DFUploadController : NSObject

@property (atomic, retain) DFUploadSessionStats *currentSessionStats;

+ (DFUploadController *)sharedUploadController;


// pass an Array of DFPhotos to be uploaded to the server aysnchronously
// subscribe to DFUploadStatusUpdate to be notified of progress
- (void)uploadPhotos:(NSArray *)photos;
- (void)cancelUpload;

@end
