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
NSString *const PhotoBasePath = @"photos/bulk/";

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
  NSArray *inviteRestDescriptors =
  [super responseDescriptorsForPeanutObjectClass:[DFPeanutPhoto class]
                                        basePath:PhotoBasePath
                                     bulkKeyPath:@"patch_photos"];
  
  return inviteRestDescriptors;
}

+ (NSArray *)requestDescriptors
{
  return [super requestDescriptorsForPeanutObjectClass:[DFPeanutPhoto class]
                                       bulkPostKeyPath:@"patch_photos"];
}


- (void)markPhotosAsNotOnSystem:(NSMutableArray *)photoIDs
                       success:(DFPeanutRestFetchSuccess)success
                       failure:(DFPeanutRestFetchFailure)failure
{
  NSMutableArray *photosToRemove = [NSMutableArray new];
  for (NSNumber *photoID in photoIDs) {
    DFPeanutPhoto *photo = [DFPeanutPhoto new];
    photo.id = photoID;
    
    // install_num is normally the install count for the user (so if they install 2 extra times, its 2
    //  Here we set it to -1 to say that this photo doesn't exist on any install anymore
    photo.install_num = @(-1);
    photo.user = [NSNumber numberWithLongLong:[[DFUser currentUser] userID]];
    [photosToRemove addObject:photo];
  }
  
  [super
   performRequest:RKRequestMethodPOST
   withPath:PhotoBasePath
   objects:photosToRemove
   parameters:nil
   forceCollection:YES
   success:^(NSArray *resultObjects) {
     success(resultObjects);
   } failure:^(NSError *error) {
     failure(error);
   }];
  
}


@end
