//
//  DFPhotoImageCache.m
//  Duffy
//
//  Created by Henry Bridge on 3/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoImageCache.h"

@interface DFPhotoImageCache()

@property (atomic, retain) NSMutableDictionary *thumbnailCache;
@property (atomic, retain) NSMutableDictionary *fullScreenImageCache;
@property (atomic, retain) NSMutableDictionary *fullImageCache;

@end

@implementation DFPhotoImageCache


static DFPhotoImageCache *defaultCache;

+ (DFPhotoImageCache *)sharedCache {
    if (!defaultCache) {
        defaultCache = [[super allocWithZone:nil] init];
    }
    return defaultCache;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedCache];
}

- (id)init
{
    self = [super init];
    if (self) {
        [self emptyCache];
    }
    return self;
}

- (UIImage *)thumbnailForPhotoWithURLString:(NSString *)photoURLString
{
    return self.thumbnailCache[photoURLString];
}

- (UIImage *)fullScreenImageForPhotoWithURLString:(NSString *)photoURLString
{
    return self.fullScreenImageCache[photoURLString];
}

- (UIImage *)fullResolutionImageForPhotoWithURLString:(NSString *)photoURLString
{
    return self.fullImageCache[photoURLString];
}

- (void)setThumbnail:(UIImage *)thumbnail forPhotoWithURLString:(NSString *)photoURLString
{
    self.thumbnailCache[photoURLString] = thumbnail;
}

- (void)setFullScreenImage:(UIImage *)fullScreenImage forPhotoWithURLString:(NSString *)photoURLString
{
    self.fullImageCache[photoURLString] = fullScreenImage;
}

- (void)setFullResolutionImage:(UIImage *)fullImage forPhotoWithURLString:(NSString *)photoURLString
{
    self.fullImageCache[photoURLString] = fullImage;
}


- (void)emptyCache
{
    self.thumbnailCache = [[NSMutableDictionary alloc] init];
    self.fullScreenImageCache = [[NSMutableDictionary alloc] init];
    self.fullImageCache = [[NSMutableDictionary alloc] init];
}


@end
