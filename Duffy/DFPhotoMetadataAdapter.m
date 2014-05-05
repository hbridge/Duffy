//
//  DFPhotoMetadataAdapter.m
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoMetadataAdapter.h"
#import <RestKit/RestKit.h>
#import "DFPhoto.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFObjectManager.h"
#import "DFNetworkingConstants.h"
#import "NSDictionary+DFJSON.h"
#import "DFPeanutPhoto.h"
#import <AFNetworking.h>
#import "DFUser.h"

/* DFPeanutBulkPhotos Mapping Class */

@interface DFPeanutBulkPhotos : NSObject

@property NSArray *bulk_photos;

@end

@implementation DFPeanutBulkPhotos

+ (RKObjectMapping *)objectMapping
{
    RKObjectMapping *bulkPhotosMapping = [RKObjectMapping mappingForClass:[DFPeanutBulkPhotos class]];

    [bulkPhotosMapping addRelationshipMappingWithSourceKeyPath:@"bulk_photos" mapping:[DFPeanutPhoto objectMapping]];
    bulkPhotosMapping.forceCollectionMapping = YES;
    
    return bulkPhotosMapping;
}

- (NSString *)arrayString
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    [result appendString:@"["];
    for (DFPeanutPhoto *peanutPhoto in self.bulk_photos) {
        [result appendString:[peanutPhoto JSONString]];
        [result appendString:@","];
    }
    if (result.length > 0) { // remove trailing comma
        NSRange lastChar;
        lastChar.location = result.length-1;
        lastChar.length = 1;
        [result deleteCharactersInRange:lastChar];
    }
    
    [result appendString:@"]"];
    return result;
}

@end


/* DFPhotoMetadataAdapter main class */

@interface DFPhotoMetadataAdapter()

@property (nonatomic, retain) RKObjectManager *objectManager;

@end


@implementation DFPhotoMetadataAdapter

+ (void)initialize
{
    [DFObjectManager registerAdapterClass:[DFPhotoMetadataAdapter class]];
}

- (id)initWithObjectManager:(RKObjectManager *)manager
{
    self = [super init];
    if (self) {
        self.objectManager = manager;
    }
    return self;
}


+ (NSArray *)requestDescriptors
{
    RKRequestDescriptor *photoDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:[[DFPeanutPhoto objectMapping] inverseMapping]
                                          objectClass:[DFPeanutPhoto class]
                                          rootKeyPath:nil
                                               method:RKRequestMethodPUT];
    
    RKRequestDescriptor *bulkPhotosDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:[[DFPeanutBulkPhotos objectMapping] inverseMapping]
                                          objectClass:[DFPeanutBulkPhotos class]
                                          rootKeyPath:@"bulk_photos"
                                               method:RKRequestMethodPOST];
    
    return [NSArray arrayWithObjects:photoDescriptor, bulkPhotosDescriptor, nil];
}

+ (NSArray *)responseDescriptors
{
    RKResponseDescriptor *bulkPhotoResponseDescriptor =
    [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutPhoto objectMapping]
                                                 method:RKRequestMethodAny
                                            pathPattern:@"photos/bulk/"
                                                keyPath:nil
                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    RKResponseDescriptor *photoResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutPhoto objectMapping]
                                                                                                 method:RKRequestMethodAny
                                                                                            pathPattern:nil
                                                                                                keyPath:nil
                                                                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    return [NSArray arrayWithObjects:photoResponseDescriptor, bulkPhotoResponseDescriptor, nil];
}

- (NSDictionary *)postPhotos:(NSArray *)photos
         appendThumbnailData:(BOOL)appendThumbnailData
{
    NSDictionary *result;
    @autoreleasepool {
        NSMutableArray *peanutPhotos = [[NSMutableArray alloc] initWithCapacity:photos.count];
        NSMutableDictionary *objectIDURLToImageData = [[NSMutableDictionary alloc] initWithCapacity:photos.count];
        unsigned long numImageBytes = 0;
        for (DFPhoto *photo in photos) {
            DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] initWithDFPhoto:photo];
            [peanutPhotos addObject:peanutPhoto];
            if (appendThumbnailData) {
                NSData *thumbnailData = photo.thumbnailData;
                objectIDURLToImageData[photo.objectID.URIRepresentation] = thumbnailData;
                numImageBytes += thumbnailData.length;
            }
        }
        DFPeanutBulkPhotos *bulkPhotos = [[DFPeanutBulkPhotos alloc] init];
        bulkPhotos.bulk_photos = peanutPhotos;
        
        NSMutableURLRequest *request = [self.objectManager
                                        multipartFormRequestWithObject:nil
                                        method:RKRequestMethodPOST
                                        path:@"photos/bulk/"
                                        parameters:@{@"bulk_photos": [bulkPhotos arrayString]}
                                        constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                            for (DFPeanutPhoto *peanutPhoto in peanutPhotos) {
                                                [formData appendPartWithFileData:objectIDURLToImageData[peanutPhoto.file_key]
                                                                            name:peanutPhoto.file_key.absoluteString
                                                                        fileName:peanutPhoto.filename
                                                                        mimeType:@"image/jpg"];
                                            }
                                        }];
        RKObjectRequestOperation *requestOperation = [self.objectManager objectRequestOperationWithRequest:request success:nil failure:nil];
        
        
        [self.objectManager enqueueObjectRequestOperation:requestOperation];
        
        [requestOperation waitUntilFinished];
        
        
        if (requestOperation.error) {
            DDLogWarn(@"DFPhotoMetadataAdapter post failed: %@", requestOperation.error.localizedDescription);
            result = @{DFUploadResultErrorKey : requestOperation.error,
                       DFUploadResultPeanutPhotos : peanutPhotos
                       };
        } else {
            NSArray *resultPhotos = [requestOperation.mappingResult array];
            result = @{DFUploadResultPeanutPhotos : resultPhotos,
                       DFUploadResultOperationType : DFPhotoUploadOperationThumbnailData,
                       DFUploadResultNumBytes : [NSNumber numberWithUnsignedLong:numImageBytes + request.HTTPBody.length],
                       };
        }
        
        
        DDLogInfo(@"thumbnail upload numImageKB:%lu requestBodyKB:%lu", numImageBytes/1024, request.HTTPBody.length/1024);
    }
    
    return result;
}

- (NSDictionary *)putPhoto:(DFPhoto *)photo
            updateMetadata:(BOOL)updateMetadata
      appendLargeImageData:(BOOL)uploadImage
{
    DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] initWithDFPhoto:photo];
    UIImage *imageToUpload = [photo scaledImageWithSmallerDimension:IMAGE_UPLOAD_SMALLER_DIMENSION];
    NSData *data = UIImageJPEGRepresentation(imageToUpload, IMAGE_UPLOAD_JPEG_QUALITY);
    NSString *photoParamater = updateMetadata ? [peanutPhoto JSONString] : [peanutPhoto photoUploadJSONString];
    
    NSString *pathString = [NSString stringWithFormat:@"photos/%llu/", photo.photoID];
    NSMutableURLRequest *request = [self.objectManager
                                    multipartFormRequestWithObject:nil
                                    method:RKRequestMethodPUT
                                    path:pathString
                                    parameters:@{@"photo": photoParamater}
                                    constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                        if (uploadImage) {
                                            [formData appendPartWithFileData:data
                                                                        name:peanutPhoto.file_key.absoluteString
                                                                    fileName:peanutPhoto.filename
                                                                    mimeType:@"image/jpg"];
                                        }
                                    }];
    RKObjectRequestOperation *requestOperation = [self.objectManager objectRequestOperationWithRequest:request success:nil failure:nil];
    [self.objectManager enqueueObjectRequestOperation:requestOperation];
    [requestOperation waitUntilFinished];
    
    NSDictionary *result;
    if (requestOperation.error) {
        DDLogWarn(@"DFPhotoMetadataAdapter put failed: %@", requestOperation.error.localizedDescription);
        result = @{DFUploadResultErrorKey : requestOperation.error,
                   DFUploadResultOperationType : DFPhotoUploadOperationFullImageData,
                   DFUploadResultNumBytes : [NSNumber numberWithUnsignedLong:data.length + request.HTTPBody.length]
                   };
    } else {
        result = @{DFUploadResultPeanutPhotos : @[peanutPhoto],
                   DFUploadResultOperationType : DFPhotoUploadOperationFullImageData,
                   DFUploadResultNumBytes : [NSNumber numberWithUnsignedLong:data.length + request.HTTPBody.length]
                   };
    }
    
    DDLogInfo(@"full image upload numImageKB:%lu requestBodyKB:%lu", data.length/1024, request.HTTPBody.length/1024);
    
    return result;
}



@end
