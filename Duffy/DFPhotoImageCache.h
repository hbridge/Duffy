//
//  DFPhotoImageCache.h
//  Duffy
//
//  Created by Henry Bridge on 3/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFPhotoImageCache : NSObject

+ (DFPhotoImageCache *)sharedCache;

- (UIImage *)thumbnailForPhotoWithURLString:(NSString *)photoURLString;
- (UIImage *)fullScreenImageForPhotoWithURLString:(NSString *)photoURLString;
- (UIImage *)fullResolutionImageForPhotoWithURLString:(NSString *)photoURLString;

- (void)setThumbnail:(UIImage *)thumbnail forPhotoWithURLString:(NSString *)photoURLString;
- (void)setFullScreenImage:(UIImage *)fullImage forPhotoWithURLString:(NSString *)photoURLString;
- (void)setFullResolutionImage:(UIImage *)fullImage forPhotoWithURLString:(NSString *)photoURLString;

- (void)emptyCache;


@end
