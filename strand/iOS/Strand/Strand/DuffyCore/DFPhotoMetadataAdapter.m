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
#import "DFPhotoStore.h"

/* DFPeanutBulkPhotos Mapping Class */

@interface DFPeanutBulkPhotos : NSObject

@property NSArray *bulk_photos;

@end

@implementation DFPeanutBulkPhotos

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *bulkPhotosMapping = [RKObjectMapping mappingForClass:[DFPeanutBulkPhotos class]];
  
  [bulkPhotosMapping addRelationshipMappingWithSourceKeyPath:@"bulk_photos"
                                                     mapping:[DFPeanutPhoto objectMapping]];
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
  if (result.length > 1) { // remove trailing comma
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
                                             method:RKRequestMethodPUT];
  
  RKRequestDescriptor *bulkPhotosDescriptor =
  [RKRequestDescriptor requestDescriptorWithMapping:[[DFPeanutBulkPhotos objectMapping] inverseMapping]
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
  
  RKResponseDescriptor *photoResponseDescriptor =
  [RKResponseDescriptor responseDescriptorWithMapping:[DFPeanutPhoto objectMapping]
                                               method:RKRequestMethodAny
                                          pathPattern:@"photos/:id/"
                                              keyPath:nil
                                          statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
  
  return [NSArray arrayWithObjects:photoResponseDescriptor, bulkPhotoResponseDescriptor, nil];
}

- (NSDictionary *)postPhotos:(NSArray *)photos
         appendThumbnailData:(BOOL)appendThumbnailData
{
  NSMutableArray *peanutPhotos = [[NSMutableArray alloc] initWithCapacity:photos.count];
  unsigned long __block numBytes = 0;
  NSDate *startDate = [NSDate date];
  for (DFPhoto *photo in photos) {
    DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] initWithDFPhoto:photo];
    [peanutPhotos addObject:peanutPhoto];
    numBytes += peanutPhoto.metadataSizeBytes;
  }
  DDLogInfo(@"Generating peanut photos for %lu photos took %.02f seconds", (unsigned long)photos.count,
            [[NSDate date] timeIntervalSinceDate:startDate]);
  
  DFPeanutBulkPhotos *bulkPhotos = [[DFPeanutBulkPhotos alloc] init];
  bulkPhotos.bulk_photos = peanutPhotos;
  
  NSMutableURLRequest *request =
  [self.objectManager
   multipartFormRequestWithObject:nil
   method:RKRequestMethodPOST
   path:@"photos/bulk/"
   parameters:@{@"bulk_photos": [bulkPhotos arrayString]}
   constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
     if (appendThumbnailData) {
       for (DFPhoto *photo in photos) {
         @autoreleasepool {
           NSData *thumbnailData = [photo thumbnailJPEGData];
           numBytes += thumbnailData.length;
           [formData appendPartWithFileData:thumbnailData
                                       name:photo.objectID.URIRepresentation.absoluteString
                                   fileName:[NSString stringWithFormat:@"%@.jpg", photo.creationHashString]
                                   mimeType:@"image/jpg"];
         }
       }
     }
   }];
  
  RKObjectRequestOperation *requestOperation = [self.objectManager
                                                objectRequestOperationWithRequest:request
                                                success:nil
                                                failure:nil];
  
  [self.objectManager enqueueObjectRequestOperation:requestOperation];
  [requestOperation waitUntilFinished];

  NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  if (requestOperation.error) {
    DDLogVerbose(@"postPhotos:appendThumbnailData failed: %@", requestOperation.error.localizedDescription);
    
    result[DFUploadResultErrorKey] = requestOperation.error;
    result[DFUploadResultPeanutPhotos] = peanutPhotos;
  } else {
    NSArray *resultPeanutPhotos = requestOperation.mappingResult.array;
    NSError *validationError = [self verifyResultPhotos:resultPeanutPhotos];
    if (validationError){
      result[DFUploadResultErrorKey] = validationError;
      result[DFUploadResultPeanutPhotos] = peanutPhotos;
    } else {
      result[DFUploadResultPeanutPhotos] = resultPeanutPhotos;
    }
  }
  
  result[DFUploadResultNumBytes] = @(numBytes);
  result[DFUploadResultOperationType] = DFPhotoUploadOperationThumbnailData;
  
  return result;
}

- (NSDictionary *)putPhoto:(DFPhoto *)photo
            updateMetadata:(BOOL)updateMetadata
      appendLargeImageData:(BOOL)uploadImage
{
  NSDictionary *result;
  @autoreleasepool {
    DFPeanutPhoto __block *peanutPhoto = [[DFPeanutPhoto alloc] initWithDFPhoto:photo];
    NSString *photoParamater =
     updateMetadata ? [peanutPhoto JSONString] : [peanutPhoto photoUploadJSONString];
    unsigned long __block imageDataBytes = 0;
    DFPhoto __block *photoToUpload = photo;
    
    NSString *pathString = [NSString stringWithFormat:@"photos/%llu/", photo.photoID];
    NSMutableURLRequest *request =
    [self.objectManager
     multipartFormRequestWithObject:nil
     method:RKRequestMethodPUT
     path:pathString
     parameters:@{@"photo": photoParamater}
     constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
       @autoreleasepool {
         if (uploadImage) {
           NSData *imageData = //photo.thumbnailData;
           [photoToUpload scaledJPEGDataWithSmallerDimension:IMAGE_UPLOAD_SMALLER_DIMENSION
                                 compressionQuality:IMAGE_UPLOAD_JPEG_QUALITY];
           imageDataBytes += imageData.length;
           [formData appendPartWithFileData:imageData
                                       name:peanutPhoto.file_key.absoluteString
                                   fileName:peanutPhoto.filename
                                   mimeType:@"image/jpg"];
         }
       }
     }];
    RKObjectRequestOperation *requestOperation = [self.objectManager
                                                  objectRequestOperationWithRequest:request
                                                  success:nil
                                                  failure:nil];
    
    [self.objectManager enqueueObjectRequestOperation:requestOperation];
    [requestOperation waitUntilFinished];
    
    if (requestOperation.error) {
      DDLogVerbose(@"DFPhotoMetadataAdapter put failed: %@",
                requestOperation.error.localizedDescription);
      result = @{DFUploadResultErrorKey : requestOperation.error,
                 DFUploadResultPeanutPhotos : @[peanutPhoto],
                 DFUploadResultOperationType : DFPhotoUploadOperationFullImageData,
                 DFUploadResultNumBytes : [NSNumber numberWithUnsignedLong:imageDataBytes]
                 };
    } else {
      result = @{DFUploadResultPeanutPhotos : [requestOperation.mappingResult array],
                 DFUploadResultOperationType : DFPhotoUploadOperationFullImageData,
                 DFUploadResultNumBytes : [NSNumber numberWithUnsignedLong:imageDataBytes]
                 };
    }
  }
  
  return  result;
}


- (NSError *)verifyResultPhotos:(NSArray *)resultPeanutPhotos
{
  NSError *error;
  
  
  if (resultPeanutPhotos == nil || resultPeanutPhotos.count == 0) {
    error = [NSError errorWithDomain:@"com.duffyapp.DFPhotoMetadataAdapter"
                                code:-3
                            userInfo:@{
                                       NSLocalizedDescriptionKey: @"The server result peanut photos array was nil or count=0"}];
  }
  
  
  for (DFPeanutPhoto *peanutPhoto in resultPeanutPhotos) {
    if (peanutPhoto.file_key == nil) {
      error = [NSError errorWithDomain:@"com.duffyapp.DFPhotoMetadataAdapter"
                                 code:-1
                             userInfo:@{
                                        NSLocalizedDescriptionKey: @"The server returned a peanutPhoto with file_key == nil"}];
      break;
    }
    
    if (![[DFPhotoStore persistentStoreCoordinator]
          managedObjectIDForURIRepresentation:peanutPhoto.file_key]){
      error = [NSError errorWithDomain:@"com.duffyapp.DFPhotoMetadataAdapter"
                                  code:-2
                              userInfo:@{
                                         NSLocalizedDescriptionKey: @"The server returned a peanutPhoto with file_key that does not exist locally"}];
      break;
    }
  }
  
  #ifdef DEBUG
  if (error) {
    [NSException raise:@"Server response failed verification"
                format:@"Reason: %@", error.localizedDescription];
  }
  #endif
  
  return error;
}




@end
