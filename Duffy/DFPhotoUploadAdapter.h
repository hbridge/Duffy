//
//  DFPhotoUploadAdapter.h
//  Duffy
//
//  Created by Henry Bridge on 4/17/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DFPhoto;

@interface DFPhotoUploadAdapter : NSObject

typedef void (^DFPhotoUploadSuccessBlock)(NSUInteger numImageBytes);
typedef void (^DFPhotoUploadFailureBlock)(NSError *error);

- (void)uploadPhoto:(DFPhoto *)photo
   withSuccessBlock:(DFPhotoUploadSuccessBlock)successHandler
       failureBlock:(DFPhotoUploadFailureBlock)failureHandler;

/* 
 Upload a photo syncrhonously and get a result dict with either an error or numImage bytes
 */
extern NSString *DFUploadResultErrorKey;
extern NSString *DFUploadResultNumBytes;

- (NSDictionary *)uploadPhoto:(DFPhoto *)photo;

- (void)cancelAllUploads;

@end
