//
//  DFUploadController.h
//  Duffy
//
//  Created by Henry Bridge on 3/11/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUploadController : NSObject

extern const NSString *DFUploadStatusUpdate;

+ (DFUploadController *)sharedUploadController;


// pass an Array of DFPhotos to be uploaded to the server aysnchronously
// subscribe to DFUploadStatusUpdate to be notified of progress
- (void)uploadPhotos:(NSArray *)photos;

@end
