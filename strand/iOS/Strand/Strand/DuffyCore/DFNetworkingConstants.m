//
//  DFNetworkingConstants.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFNetworkingConstants.h"

@implementation DFNetworkingConstants

#ifdef DEBUG
NSString const *DFServerBaseURL = @"http://dev.strand.duffyapp.com";
#else
NSString const *DFServerBaseURL = @"http://prod.strand.duffyapp.com";
#endif
NSString const *DFServerAPIPath = @"/strand/api/";
NSString const *DFServerPortDefault = @"";

// common parameters
NSString const *DFUserIDParameterKey = @"user_id";
NSString const *DFDeviceIDParameterKey = @"phone_id";


// Upload quality constants
CGFloat const IMAGE_UPLOAD_SMALLER_DIMENSION = 569.0;
float const IMAGE_UPLOAD_JPEG_QUALITY = 90.0;
CGFloat const IMAGE_UPLOAD_MAX_LENGTH = 1136.0;


DFPhotoUploadOperationImageDataType DFPhotoUploadOperationThumbnailData = @"DFPhotoUploadOperationThumbnailData";
DFPhotoUploadOperationImageDataType DFPhotoUploadOperationFullImageData = @"DFPhotoUploadOperationFullImageData";


// Result dict strings
NSString const *DFUploadResultErrorKey = @"DFUploadResultError";
NSString const *DFUploadResultOperationType = @"DFUploadResultOperationType";
NSString const *DFUploadResultPeanutPhotos = @"DFUploadResultPeanutPhotos";
NSString const *DFUploadResultNumBytes = @"DFUploadNumBytes";
NSString const *DFUploadResultPhotoID = @"DFUploadResultPhotoID";





@end
