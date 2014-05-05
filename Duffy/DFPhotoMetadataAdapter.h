//
//  DFPhotoMetadataAdapter.h
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFNetworkAdapter.h"

@class RKObjectManager;
@class DFPhoto;

@interface DFPhotoMetadataAdapter : NSObject <DFNetworkAdapter>

- (id)initWithObjectManager:(RKObjectManager *)manager;

- (NSDictionary *)postPhotos:(NSArray *)photos
         appendThumbnailData:(BOOL)appendThumbnailData;
- (NSDictionary *)putPhoto:(DFPhoto *)photo
            updateMetadata:(BOOL)updateMetadata
      appendLargeImageData:(BOOL)uploadImage;


@end
