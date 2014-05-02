//
//  DFPhotoUploadAdapter.h
//  Duffy
//
//  Created by Henry Bridge on 4/17/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkingConstants.h"

@class DFPhoto;

@interface DFPhotoImageDataAdapter : NSObject

typedef void (^DFPhotoUploadSuccessBlock)(NSUInteger numImageBytes);
typedef void (^DFPhotoUploadFailureBlock)(NSError *error);

- (void)uploadPhoto:(DFPhoto *)photo
   withSuccessBlock:(DFPhotoUploadSuccessBlock)successHandler
       failureBlock:(DFPhotoUploadFailureBlock)failureHandler;

/* 
 Upload a photo syncrhonously and get a result dict with either an error or numImage bytes
 */

- (NSDictionary *)uploadPhoto:(DFPhoto *)photo;

- (void)cancelAllUploads;

@end
