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
#import "DFAnalytics.h"
#import "NSString+DFHelpers.h"

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

- (id)init
{
  self = [super init];
  if (self) {
    self.objectManager = [DFObjectManager sharedManager];
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
    @try {
      DFPeanutPhoto *peanutPhoto = [[DFPeanutPhoto alloc] initWithDFPhoto:photo];
      [peanutPhotos addObject:peanutPhoto];
      numBytes += peanutPhoto.metadataSizeBytes;
    }
    @catch (NSException *exception) {
      DDLogError(@"%@ postPhotos:appendThumbnailData skipping photo error: %@", self.class, exception);
      continue;
    }
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
           dispatch_semaphore_t thumbnailSemaphore = dispatch_semaphore_create(0);
           NSData __block *thumbnailData;
           [photo.asset loadThubnailJPEGData:^(NSData *data) {
             thumbnailData = data;
             dispatch_semaphore_signal(thumbnailSemaphore);
           } failure:^(NSError *error) {
             dispatch_semaphore_signal(thumbnailSemaphore);
           }];
           dispatch_semaphore_wait(thumbnailSemaphore, DISPATCH_TIME_FOREVER);
           
           if (thumbnailData) {
             numBytes += thumbnailData.length;
             [formData appendPartWithFileData:thumbnailData
                                         name:photo.objectID.URIRepresentation.absoluteString
                                     fileName:[NSString stringWithFormat:@"%@.jpg", photo.asset.hashString]
                                     mimeType:@"image/jpg"];
           } else {
             DDLogError(@"Thumbnail data nil for upload");
           }
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
  if (appendThumbnailData) {
    result[DFUploadResultOperationType] = DFPhotoUploadOperationThumbnailData;
  } else {
    result[DFUploadResultOperationType] = DFPhotoUploadOperationMetadata;
  }
  
  return result;
}

- (NSDictionary *)putPhoto:(DFPhoto *)photo
            updateMetadata:(BOOL)updateMetadata
      appendLargeImageData:(BOOL)uploadImage
{
  NSDictionary *result;
  @autoreleasepool {
    DFPeanutPhoto __block *peanutPhoto;
    @try {
      peanutPhoto = [[DFPeanutPhoto alloc] initWithDFPhoto:photo];
    }
    @catch (NSException *exception) {
      DDLogError(@"%@ postPhotos:appendThumbnailData skipping photo error: %@", self.class, exception);
      NSError *error = [NSError errorWithDomain:@"com.duffyapp.strand"
                                           code:-1
                                       userInfo:@{
                                                  NSLocalizedDescriptionKey: exception.description
                                                  }];
      return @{DFUploadResultErrorKey : error,
               DFUploadResultPeanutPhotos : @[],
               DFUploadResultOperationType : DFPhotoUploadOperationFullImageData,
               DFUploadResultNumBytes : @(0)
               };
    }
    NSString *photoParamater =
     updateMetadata ? [peanutPhoto JSONString] : [peanutPhoto photoUploadJSONString];
    unsigned long __block imageDataBytes = 0;
    
    NSString *pathString = [NSString stringWithFormat:@"photos/%llu/", photo.photoID];
    BOOL __block doneConstructingFormRequest = NO;
    NSError __block *appendDataError;
    NSMutableURLRequest *request =
    [self.objectManager
     multipartFormRequestWithObject:nil
     method:RKRequestMethodPUT
     path:pathString
     parameters:@{@"photo": photoParamater}
     constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
       @autoreleasepool {
         if (uploadImage) {
           // Create a load_semaphore to block the constructingBodyWithBlock callback
           dispatch_semaphore_t load_semaphore = dispatch_semaphore_create(0);
           NSData __block *imageData = nil;
           [photo.asset
            loadJPEGDataWithImageLength:IMAGE_UPLOAD_MAX_LENGTH
            compressionQuality:IMAGE_UPLOAD_JPEG_QUALITY
            success:^(NSData *data) {
              imageData = data;
              if (doneConstructingFormRequest)
                DDLogError(@"%@ loadJPEGDataSuccess after doneAppendingData true.",
                                                self.class);
              if (!data) DDLogError(@"%@ data for form post nil!", self.class);
              dispatch_semaphore_signal(load_semaphore);
            } failure:^(NSError *error) {
              DDLogError(@"Error: error loading image data for photo id %llu. error: %@",
                         photo.photoID, error);
              appendDataError = error;
              dispatch_semaphore_signal(load_semaphore);
            }];
           
           // We need to wait on the image data load before we let the callback return,
           // otherwise, the form may contain no data
           dispatch_semaphore_wait(load_semaphore, DISPATCH_TIME_FOREVER);
           
           if (imageData) {
             imageDataBytes += imageData.length;
             DDLogVerbose(@"%@ appending image with key: %@, filename:%@ and %@ bytes to form post",
                          self.class,
                          peanutPhoto.file_key.absoluteString,
                          peanutPhoto.filename,
                          @(imageData.length));
             [formData appendPartWithFileData:imageData
                                         name:peanutPhoto.file_key.absoluteString
                                     fileName:peanutPhoto.filename
                                     mimeType:@"image/jpg"];
           } else {
             DDLogVerbose(@"%@ reultData nil, not appending data.", self.class);
             if (!appendDataError) appendDataError =
               [NSError
                errorWithDomain:@"com.duffyapp.strand"
                code:-66
                userInfo:@{NSLocalizedDescriptionKey: @"Asset returned nil data with no explanation."}];
           }
         }
       }
     }];
    
    doneConstructingFormRequest = YES;
    RKObjectRequestOperation *requestOperation = [self.objectManager
                                                  objectRequestOperationWithRequest:request
                                                  success:nil
                                                  failure:nil];
    
    [self.objectManager enqueueObjectRequestOperation:requestOperation];
    
    DDLogVerbose(@"%@ request: %@ \n body: %@",
                 [self.class description],
                 request.URL.absoluteString,
                 [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
    
    [requestOperation waitUntilFinished];
    
    if (requestOperation.error || appendDataError) {
      NSError *nonNilError = appendDataError ? appendDataError : requestOperation.error;
      DDLogVerbose(@"DFPhotoMetadataAdapter put failed: %@",
                nonNilError.localizedDescription);
      result = @{DFUploadResultErrorKey : nonNilError,
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

- (void)getPhotoMetadata:(DFPhotoIDType)photoID
         completionBlock:(DFMetadataFetchCompletionBlock)completionBlock
{
  DFPeanutPhoto *requestPhoto = [[DFPeanutPhoto alloc] init];
  requestPhoto.id = @(photoID);
  
  NSMutableURLRequest *request =
  [self.objectManager
   requestWithObject:requestPhoto
   method:RKRequestMethodGET
   path:[NSString stringWithFormat:@"photos/%llu", photoID]
   parameters:nil];
  
  DDLogInfo(@"DFPhotoMetadataAdapter getting endpoint: %@", request.URL.absoluteString);
  
  RKObjectRequestOperation *requestOperation =
  [self.objectManager
   objectRequestOperationWithRequest:request
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
     DFPeanutPhoto *resultPeanutPhoto = mappingResult.firstObject;
     NSDictionary *resultDict = [NSDictionary dictionaryWithJSONString:resultPeanutPhoto.metadata];
     completionBlock(resultDict);
   } failure:^(RKObjectRequestOperation *operation, NSError *error) {
     DDLogWarn(@"DFPhotoMetadataAdapter metadata fetch failed: %@", error.description);
     completionBlock(nil);
   }];
                                                
  [self.objectManager enqueueObjectRequestOperation:requestOperation];
}

- (void)deletePhoto:(DFPhotoIDType)photoID
    completionBlock:(DFPhotoDeleteCompletionBlock)completionBlock
{
  DFPeanutPhoto *requestPhoto = [[DFPeanutPhoto alloc] init];
  requestPhoto.id = @(photoID);
  
  NSMutableURLRequest *request =
  [self.objectManager
   requestWithObject:requestPhoto
   method:RKRequestMethodDELETE
   path:[NSString stringWithFormat:@"photos/%llu", photoID]
   parameters:nil];
  
  DDLogInfo(@"DFPhotoMetadataAdapter getting endpoint: %@", request.URL.absoluteString);
  
  RKObjectRequestOperation *requestOperation =
  [self.objectManager
   objectRequestOperationWithRequest:request
   success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
     DDLogVerbose(@"Delete server response: %@", mappingResult.firstObject);
     completionBlock(nil);
   } failure:^(RKObjectRequestOperation *operation, NSError *error) {
     DDLogWarn(@"DFPhotoMetadataAdapter delete failed: %@", error.description);
     completionBlock(error);
   }];
  
  [self.objectManager enqueueObjectRequestOperation:requestOperation];
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

+ (NSURL *)urlForPhotoID:(DFPhotoIDType)photoID
{
  return [[[DFUser currentUser] apiURL]
          URLByAppendingPathComponent:[NSString stringWithFormat:@"photos/%llu", photoID]];
}


@end
