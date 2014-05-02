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
        NSDictionary *JSONSafeDict = [peanutPhoto.dictionary dictionaryWithNonJSONRemoved];
        [result appendString:[JSONSafeDict JSONString]];
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
    RKRequestDescriptor *photoDescriptor =
    [RKRequestDescriptor requestDescriptorWithMapping:[[DFPeanutPhoto objectMapping] inverseMapping]
                                          objectClass:[DFPeanutPhoto class]
                                          rootKeyPath:nil
                                               method:RKRequestMethodPOST];
    
    RKRequestDescriptor *bulkPhotosDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:[[DFPeanutBulkPhotos objectMapping] inverseMapping]
                                          objectClass:[DFPeanutBulkPhotos class]
                                          rootKeyPath:@"bulk_photos"
                                               method:RKRequestMethodPOST];
    

    
//    return [NSArray arrayWithObjects:photoDescriptor, nil];
    return [NSArray arrayWithObjects:photoDescriptor, bulkPhotosDescriptor, nil];
}

+ (NSArray *)responseDescriptors
{
    RKResponseDescriptor *photoResponseDescriptor =
    [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutPhoto objectMapping]
                                                 method:RKRequestMethodAny
                                            pathPattern:@"photos/bulk/"
                                                keyPath:nil
                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
//    RKResponseDescriptor *bulkResponseDescriptor =
//    [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutBulkPhotos objectMapping]
//                                                 method:RKRequestMethodAny
//                                            pathPattern:@"photos/bulk/"
//                                                keyPath:nil
//                                            statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
        return [NSArray arrayWithObjects:photoResponseDescriptor, nil];
//    return [NSArray arrayWithObjects:photoResponseDescriptor, bulkResponseDescriptor, nil];
}

- (NSDictionary *)postPhotosWithFullImages:(NSArray *)photos
{
    DDLogInfo(@"%@ postPhotosWithFullData", [[self class] description]);
    return [self postPhotos:photos appendThumbnailData:NO appendFullImageData:YES];
}

- (NSDictionary *)postPhotosWithThumbnails:(NSArray *)photos
{
    DDLogInfo(@"%@ postPhotosWithThumbnails count %lu", [[self class] description], photos.count);
    
    return [self postPhotos:photos appendThumbnailData:YES appendFullImageData:NO];
}

- (NSDictionary *)postPhotos:(NSArray *)photos
         appendThumbnailData:(BOOL)appendThumbnailData
         appendFullImageData:(BOOL)appendFullImageData
{
    NSMutableArray *peanutPhotos = [[NSMutableArray alloc] initWithCapacity:photos.count];
    NSMutableDictionary *objectIDURLToImageData = [[NSMutableDictionary alloc] initWithCapacity:photos.count];
    NSMutableDictionary *objectIDURLToDimensionsData = [[NSMutableDictionary alloc] initWithCapacity:photos.count];
    for (DFPhoto *photo in photos) {
        [peanutPhotos addObject:[[DFPeanutPhoto alloc] initWithDFPhoto:photo]];
        if (appendThumbnailData) {
            objectIDURLToImageData[photo.objectID.URIRepresentation] = photo.thumbnailData;
            objectIDURLToDimensionsData[photo.objectID.URIRepresentation] = [NSValue valueWithCGSize:CGSizeMake(157, 157)];
        } else if (appendFullImageData) {
            UIImage *imageToUpload = [photo scaledImageWithSmallerDimension:IMAGE_UPLOAD_SMALLER_DIMENSION];
            NSData *data = UIImageJPEGRepresentation(imageToUpload, IMAGE_UPLOAD_JPEG_QUALITY);
            objectIDURLToImageData[photo.objectID.URIRepresentation] = data;
            objectIDURLToDimensionsData[photo.objectID.URIRepresentation] = [NSValue valueWithCGSize:imageToUpload.size];
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
                                            NSString *fileName = [NSString stringWithFormat:@"%@.jpg", peanutPhoto.hash];
                                            [formData appendPartWithFileData:objectIDURLToImageData[peanutPhoto.key]
                                                                        name:peanutPhoto.key.absoluteString
                                                                    fileName:fileName
                                                                    mimeType:@"image/jpg"];
                                        }
                                    }];
    RKObjectRequestOperation *requestOperation = [self.objectManager objectRequestOperationWithRequest:request success:nil failure:nil];
    
    
    [self.objectManager enqueueObjectRequestOperation:requestOperation];
    
    [requestOperation waitUntilFinished];
    
    NSDictionary *result;
    if (requestOperation.error) {
        DDLogWarn(@"DFPhotoMetadataAdapter post failed: %@", requestOperation.error.localizedDescription);
        result = @{DFUploadResultErrorKey : requestOperation.error};
    } else {
        NSArray *resultPhotos = [requestOperation.mappingResult array];
        for (DFPeanutPhoto *peanutPhoto in resultPhotos) {
            peanutPhoto.uploaded_dimensions = @[objectIDURLToDimensionsData[peanutPhoto.key]];
            peanutPhoto.uploaded_image_bytes = [(NSData *)objectIDURLToImageData[peanutPhoto.key] length];
        }
        result = @{DFUploadResultPeanutPhotos : resultPhotos};
    }
    
    return result;
}



@end
