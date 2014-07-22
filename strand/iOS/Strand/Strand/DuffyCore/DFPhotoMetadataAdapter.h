//
//  DFPhotoMetadataAdapter.h
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPhoto.h"
#import "DFNetworkAdapter.h"

@class DFPeanutPhoto;

@class RKObjectManager;

typedef void (^DFPhotoFetchCompletionBlock)(DFPeanutPhoto *peanutPhoto,
                                            NSDictionary *imageData,
                                            NSError *error);
typedef void (^DFImageDataFetchCompletionBlock)(NSDictionary *imageData, NSError *error);
typedef void (^DFMetadataFetchCompletionBlock)(NSDictionary *metadata);
typedef void (^DFPhotoDeleteCompletionBlock)(NSError *error);

@interface DFPhotoMetadataAdapter : NSObject <DFNetworkAdapter>

- (id)initWithObjectManager:(RKObjectManager *)manager;

- (NSDictionary *)postPhotos:(NSArray *)photos
         appendThumbnailData:(BOOL)appendThumbnailData;
- (NSDictionary *)putPhoto:(DFPhoto *)photo
            updateMetadata:(BOOL)updateMetadata
      appendLargeImageData:(BOOL)uploadImage;
- (void)getPhotoMetadata:(DFPhotoIDType)photoID
         completionBlock:(DFMetadataFetchCompletionBlock)completionBlock;

- (void)getPhoto:(DFPhotoIDType)photoID
withImageDataTypes:(DFImageType)imageTypes
 completionBlock:(DFPhotoFetchCompletionBlock)completionBlock;

/* 
 takes a dictionary of format {DFImageType type : NSString *imagePath} and calls
 a completion with a dict of format {DFImageType type : NSData *imageData} 
 */
- (void)getImageDataForTypesWithPaths:(NSDictionary *)dict
       withCompletionBlock:(DFImageDataFetchCompletionBlock)completion;

- (void)deletePhoto:(DFPhotoIDType)photoID
    completionBlock:(DFPhotoDeleteCompletionBlock)completionBlock;

+ (NSURL *)urlForPhotoID:(DFPhotoIDType)photoID;

@end
