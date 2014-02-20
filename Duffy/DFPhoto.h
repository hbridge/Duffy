//
//  DFPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALAsset;

@interface DFPhoto : NSObject

- (id)initWithAsset:(ALAsset *)asset;
- (id)initWithURL:(NSURL *)url;

// use these to determine whether asking for the full image will trigger
// a fault, potentially causing UI slowness
- (BOOL)isFullImageFault;
- (BOOL)isThumbnailFault;

// use these to force the class to cache the image data so it can
// be accessed quickly in the future
- (void)loadFullImage;
- (void)loadThumbnail;

// actual image data for thumbnail and fullImage, may trigger a fault
// (even network access) and take awhile to load.
- (UIImage *)thumbnail;
- (UIImage *)fullImage;


@end
