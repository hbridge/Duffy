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

@class RKObjectManager;

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

- (void)deletePhoto:(DFPhotoIDType)photoID
    completionBlock:(DFPhotoDeleteCompletionBlock)completionBlock;

@end
