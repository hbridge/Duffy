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
NSString const *DFServerBaseHost = @"dev.strand.duffyapp.com";
NSString const *DFServerBaseURL = @"http://dev.strand.duffyapp.com";
NSString const *DFServerScheme = @"http";
NSString const *DFImageServerBaseURL = @"https://s3-external-1.amazonaws.com/strand-dev";
int DFSocketPort = 8005;
#else
NSString const *DFServerBaseHost = @"prod.strand.duffyapp.com";
NSString const *DFServerBaseURL = @"https://prod.strand.duffyapp.com";
NSString const *DFServerScheme = @"https";
NSString const *DFImageServerBaseURL = @"https://s3-external-1.amazonaws.com/strand-prod";
int DFSocketPort = 8005;
#endif
NSString const *DFServerAPIPath = @"/strand/api/v1/";
NSString const *DFServerPortDefault = @"";

// common parameters
NSString const *DFUserIDParameterKey = @"user_id";
NSString const *DFDeviceIDParameterKey = @"phone_id";
NSString const *DFAuthTokenParameterKey = @"auth_token";

NSString const *BuildOSKey = @"build_os";
NSString const *BuildNumberKey = @"build_number";
NSString const *BuildIDKey = @"build_id";

// Upload quality constants
float const IMAGE_UPLOAD_JPEG_QUALITY = 0.6;
CGFloat const IMAGE_UPLOAD_MAX_LENGTH = 1920.0;

DFPhotoUploadOperationImageDataType DFPhotoUploadOperationMetadata = @"DFPhotoUploadOperationMetadata";
DFPhotoUploadOperationImageDataType DFPhotoUploadOperationThumbnailData = @"DFPhotoUploadOperationThumbnailData";
DFPhotoUploadOperationImageDataType DFPhotoUploadOperationFullImageData = @"DFPhotoUploadOperationFullImageData";


// Result dict strings
NSString const *DFUploadResultErrorKey = @"DFUploadResultError";
NSString const *DFUploadResultOperationType = @"DFUploadResultOperationType";
NSString const *DFUploadResultPeanutPhotos = @"DFUploadResultPeanutPhotos";
NSString const *DFUploadResultNumBytes = @"DFUploadNumBytes";
NSString const *DFUploadResultPhotoID = @"DFUploadResultPhotoID";

NSString *const DFSupportPageURLString = @"http://www.duffyapp.com/strand/support";
NSString *const DFTermsPageURLString = @"http://www.duffyapp.com/strand/terms.html";
NSString *const DFPrivacyPageURLString = @"http://www.duffyapp.com/strand/privacy.html";
NSString *const DFAcknowledgementsPageURLString = @"http://www.duffyapp.com/strand/acknowledgements.html";


@end
