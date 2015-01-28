//
//  DFPeanutPhotoAdapter.m
//  Strand
//
//  Created by Derek Parham on 10/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPeanutPhotoAdapter.h"
#import "DFPeanutPhoto.h"
#import "DFObjectManager.h"
#import "DFUser.h"

// We are currently overloading the photos/bulk endpoint but are using a different key than photo uploading.
//   Instead, this adapter uses "patch_photos", logic is done on the backend to figure out what to do differently.
NSString *const PhotoBulkBasePath = @"photos/bulk/";
NSString *const PhotoBasePath = @"photos/";

/*
 *
 */

@implementation DFPeanutPhotoAdapter


+ (void)initialize
{
  [DFObjectManager registerAdapterClass:[self class]];
}

+ (NSArray *)responseDescriptors
{
  NSArray *bulkDescriptors = [super responseDescriptorsForPeanutObjectClass:[DFPeanutPhoto class]
                                                                   basePath:PhotoBulkBasePath
                                                                bulkKeyPath:@"patch_photos"];
  
  NSArray *baseDescriptors = [super responseDescriptorsForPeanutObjectClass:[DFPeanutPhoto class]
                                                                   basePath:PhotoBasePath
                                                                bulkKeyPath:nil];
  NSMutableArray *descriptors = [NSMutableArray new];
  [descriptors addObjectsFromArray:bulkDescriptors];
  [descriptors addObjectsFromArray:baseDescriptors];
  return descriptors;
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutPhoto class]
                                       bulkPostKeyPath:@"patch_photos"];
}

- (void)photoWithID:(DFPhotoIDType)photoID
                       success:(DFPeanutRestFetchSuccess)success
                       failure:(DFPeanutRestFetchFailure)failure
{
  DFPeanutPhoto *photo = [DFPeanutPhoto new];
  photo.id = @(photoID);
  [super
   performRequest:RKRequestMethodGET
   withPath:PhotoBasePath
   objects:@[photo]
   parameters:nil
   forceCollection:NO
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}

- (void)patchPhotos:(NSArray *)peanutPhotos success:(DFPeanutRestFetchSuccess)success failure:(DFPeanutRestFetchFailure)failure
{
  [super
   performRequest:RKRequestMethodPOST // using POST here is intentional, as we had to hack the patch functionality on the backend
   withPath:PhotoBulkBasePath
   objects:peanutPhotos
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
}


@end
