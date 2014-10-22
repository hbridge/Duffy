//
//  DFImageDownloadManager.h
//  Strand
//
//  Created by Derek Parham on 10/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^DFImageFetchCompletionBlock)(UIImage *image, NSError *error);

@class RKObjectManager;

@interface DFImageDownloadManager : NSObject

+ (DFImageDownloadManager *)sharedManager;

- (void)fetchNewImages;
- (void)fetchImageDataForImageType:(DFImageType)type andPhotoID:(DFPhotoIDType)photoID;

@end
