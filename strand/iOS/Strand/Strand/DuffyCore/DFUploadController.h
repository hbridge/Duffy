//
//  DFUploadController2.h
//  Duffy
//
//  Created by Henry Bridge on 4/25/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFUploadSessionStats.h"

@class DFPhoto;

@interface DFUploadController : NSObject

+ (DFUploadController *)sharedUploadController;
- (void)uploadPhotos;
- (void)cancelUploads;
- (BOOL)isUploadInProgress;

@property (readonly, nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@end
