//
//  DFPhotoUploadAdapter.m
//  Duffy
//
//  Created by Henry Bridge on 4/17/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoUploadAdapter.h"
#import <RestKit/RestKit.h>
#import "DFPhoto.h"
#import "DFPhoto+FaceDetection.h"
#import "DFUser.h"
#import "NSDictionary+DFJSON.h"

// Private DFUploadResponse Class
@interface DFUploadResponse : NSObject
@property (nonatomic, retain) NSString *result;
@property (nonatomic, retain) NSString *debug;
@end
@implementation DFUploadResponse
@end

// Constants
static NSString *AddPhotoResource = @"/api/addPhoto";
static NSString *UserIDParameterKey = @"phone_id";
static NSString *PhotoMetadataKey = @"photo_metadata";
static NSString *PhotoLocationKey = @"location_data";
static NSString *PhotoFacesKey = @"iphone_faceboxes_topleft";

static const CGFloat IMAGE_UPLOAD_SMALLER_DIMENSION = 569.0;
static const float IMAGE_UPLOAD_JPEG_QUALITY = 90.0;

static const unsigned int FaceDetectionMinMemory = 1000;


@interface DFPhotoUploadAdapter()

@property (nonatomic, retain) RKObjectManager *objectManager;

@end

@implementation DFPhotoUploadAdapter

- (void)uploadPhoto:(DFPhoto *)photo
   withSuccessBlock:(DFPhotoUploadSuccessBlock)successHandler
       failureBlock:(DFPhotoUploadFailureBlock)failureHandler
{
    NSURLRequest *postRequest = [self createPostRequestForPhoto:photo];
    
    NSNumber *numBytes = [NSURLProtocol propertyForKey:@"DFPhotoNumBytes" inRequest:postRequest];
    
    RKObjectRequestOperation *operation =
    [[self objectManager]
     objectRequestOperationWithRequest:postRequest
     success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult)
     {
         DFUploadResponse *response = [mappingResult firstObject];
         if ([response.result isEqualToString:@"true"]) {
             photo.uploadDate = [NSDate date];
             successHandler(numBytes.unsignedIntegerValue);
         } else {
             DDLogWarn(@"File did not upload properly.  Retrying.");
             failureHandler([NSError errorWithDomain:@"com.duffyapp.UploadError" code:-10 userInfo:nil]);
         }
     }
     failure:^(RKObjectRequestOperation *operation, NSError *error)
     {
         DDLogError(@"Upload failed.  Error: %@", error.localizedDescription);
         failureHandler(error);
     }];
    
    
    [[self objectManager] enqueueObjectRequestOperation:operation]; // NOTE: Must be enqueued rather than started
}


- (NSMutableURLRequest *)createPostRequestForPhoto:(DFPhoto *)photo
{
    UIImage *imageToUpload = [photo scaledImageWithSmallerDimension:IMAGE_UPLOAD_SMALLER_DIMENSION];
    NSData *imageData = UIImageJPEGRepresentation(imageToUpload, IMAGE_UPLOAD_JPEG_QUALITY);
    NSDictionary *postParameters = [self postParametersForPhoto:photo];
    NSString *uniqueFilename = [NSString stringWithFormat:@"photo_%@.jpg", [[NSUUID UUID] UUIDString]];
    
    
    NSMutableURLRequest *request = [[self objectManager] multipartFormRequestWithObject:nil
                                                                                 method:RKRequestMethodPOST
                                                                                   path:AddPhotoResource
                                                                             parameters:postParameters
                                                              constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                                                  [formData appendPartWithFileData:imageData
                                                                                              name:@"file"
                                                                                          fileName:uniqueFilename
                                                                                          mimeType:@"image/jpg"];
                                                              }];
    [NSURLProtocol setProperty:[NSNumber numberWithUnsignedInteger:imageData.length] forKey:@"DFPhotoNumBytes" inRequest:request];
    
    return request;
}

- (NSDictionary *)postParametersForPhoto:(DFPhoto *)photo
{
    NSString *faceInfoJSONString;
    if ([[DFUser currentUser] devicePhysicalMemoryMB] >= FaceDetectionMinMemory) {
        faceInfoJSONString = [self faceJSONStringForPhoto:photo];
    } else {
        faceInfoJSONString = @"{}";
    }
    
    
    NSDictionary *params = @{
                             UserIDParameterKey: [[DFUser currentUser] deviceID],
                             PhotoMetadataKey: [self metadataJSONStringForPhoto:photo],
                             PhotoLocationKey: [self locationJSONStringForPhoto:photo],
                             PhotoFacesKey:    faceInfoJSONString,
                             };
    
    return params;
}


- (NSString *)metadataJSONStringForPhoto:(DFPhoto *)photo
{
    NSDictionary *jsonSafeMetadataDict = [[photo metadataDictionary] dictionaryWithNonJSONRemoved];
    return [jsonSafeMetadataDict JSONString];
}

- (NSString *)locationJSONStringForPhoto:(DFPhoto *)photo
{
    if (photo.location == nil) {
        return [@{} JSONString];
    }
    
    
    NSDictionary __block *resultDictionary;
    
    // safe to call this here as we're on the uploader dispatch queue and
    // the reverse geocoder call back will happen on main thread, per the docs
    
    dispatch_semaphore_t reverseGeocodeSemaphore = dispatch_semaphore_create(0);
    [photo fetchReverseGeocodeDictionary:^(NSDictionary *locationDict) {
        resultDictionary = locationDict;
        dispatch_semaphore_signal(reverseGeocodeSemaphore);
    }];
    
    dispatch_semaphore_wait(reverseGeocodeSemaphore, DISPATCH_TIME_FOREVER);
    
    
    return [resultDictionary JSONString];
}

- (NSString *)faceJSONStringForPhoto:(DFPhoto *)photo
{
    NSArray __block *resultArray;
    
    dispatch_semaphore_t faceDetectSemaphore = dispatch_semaphore_create(0);
    [photo faceFeaturesInPhoto:^(NSArray *features) {
        resultArray = features;
        dispatch_semaphore_signal(faceDetectSemaphore);
    }];
    
    dispatch_semaphore_wait(faceDetectSemaphore, DISPATCH_TIME_FOREVER);
    
    NSMutableDictionary *resultDictionary = [[NSMutableDictionary alloc] init];
    for (CIFaceFeature *faceFeature in resultArray) {
        NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)resultDictionary.count];
        resultDictionary[key] = @{@"bounds": NSStringFromCGRect(faceFeature.bounds),
                                  @"has_smile" : [NSNumber numberWithBool:faceFeature.hasSmile],
                                  };
    }
    
    return [resultDictionary JSONString];
}

#pragma mark - Internal Helper Functions


- (RKObjectManager *)objectManager {
    if (!_objectManager) {
        NSURL *baseURL = [[DFUser currentUser] serverURL];
        _objectManager = [RKObjectManager managerWithBaseURL:baseURL];
        
        // generate response mapping
        RKObjectMapping *responseMapping = [RKObjectMapping mappingForClass:[DFUploadResponse class]];
        [responseMapping addAttributeMappingsFromArray:@[@"result", @"debug"]];
        
        RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:responseMapping
                                                                                                method:RKRequestMethodPOST
                                                                                           pathPattern:AddPhotoResource
                                                                                               keyPath:nil
                                                                                           statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        
        [_objectManager addResponseDescriptor:responseDescriptor];
    }
    return _objectManager;
}


@end
