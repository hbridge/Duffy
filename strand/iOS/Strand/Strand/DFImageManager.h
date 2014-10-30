//
//  DFImageManager.h
//  Strand
//
//  Created by Henry Bridge on 10/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFImageManagerRequest.h"

@interface DFImageManager : NSObject

typedef void (^SetImageCompletion)(NSError *error);

+ (DFImageManager *)sharedManager;

- (void)imageForID:(DFPhotoIDType)photoID
     preferredType:(DFImageType)type
        completion:(ImageLoadCompletionBlock)completionBlock;

- (void)imageForID:(DFPhotoIDType)photoID
              size:(CGSize)size
       contentMode:(DFImageRequestContentMode)contentMode
      deliveryMode:(DFImageRequestDeliveryMode)deliveryMode
        completion:(ImageLoadCompletionBlock)completionBlock;


- (void)startCachingImagesForPhotoIDs:(NSArray *)photoIDs
                           targetSize:(CGSize)size
                          contentMode:(DFImageRequestContentMode)contentMode;
- (void)clearCache;


@end
