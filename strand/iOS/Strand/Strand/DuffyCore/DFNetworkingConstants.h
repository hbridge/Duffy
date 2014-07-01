//
//  DFNetworkingConstants.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFNetworkingConstants : NSObject

extern NSString *DFServerBaseURL;
extern NSString *DFServerAPIPath;


// common parameters
extern NSString *DFUserIDParameterKey;
extern NSString *DFDeviceIDParameterKey;

// User ID constants
extern NSString *DFGetUserPath;
extern NSString *DFCreateUserPath;
extern NSString *DFDeviceNameParameterKey;

// Upload quality constants
extern const CGFloat IMAGE_UPLOAD_SMALLER_DIMENSION;
extern const float IMAGE_UPLOAD_JPEG_QUALITY;
extern CGFloat const IMAGE_UPLOAD_MAX_LENGTH;

typedef NSString* const DFPhotoUploadOperationImageDataType;
extern DFPhotoUploadOperationImageDataType DFPhotoUploadOperationThumbnailData;
extern DFPhotoUploadOperationImageDataType DFPhotoUploadOperationFullImageData;

extern NSString *DFUploadResultErrorKey;
extern NSString const *DFUploadResultPeanutPhotos;
extern NSString *DFUploadResultNumBytes;
extern NSString *DFUploadResultPhotoID;
extern NSString const *DFUploadResultOperationType;

@end
