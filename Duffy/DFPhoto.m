//
//  DFPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface DFPhoto()

@property (nonatomic, retain) ALAsset *asset;
@property (nonatomic, retain) NSURL *remoteURL;
@property (nonatomic, retain) UIImage *fullImage;
@property (nonatomic, retain) UIImage *thumbnail;

@end


@implementation DFPhoto


- (id)initWithAsset:(ALAsset *)asset;
{
    self = [super init];
    if (self) {
        self.asset = asset;
        
    }
    return self;
}

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.remoteURL = url;
    }
    return self;
}

- (void)loadThumbnail
{
    [self loadThumbnailFromRemoteURL];
}

- (UIImage *)thumbnail {
    if (!_thumbnail){
        if (self.asset) {
            CGImageRef imageRef = [self.asset thumbnail];
            self.thumbnail = [UIImage imageWithCGImage:imageRef];
        } else if (self.remoteURL) {
            if (!self.fullImage) {
                [self loadFullImageFromRemoteURL];
            }
            
            self.thumbnail = self.fullImage;
        }
    }
    
    return _thumbnail;
}

- (void)loadFullImage
{
    if (self.asset) {
        CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
        self.fullImage = [UIImage imageWithCGImage:imageRef];
    } else if (self.remoteURL) {
        [self loadFullImageFromRemoteURL];
    }
}

- (UIImage *)fullImage
{
    if (_fullImage) {
        [self loadFullImage];
    }
    
    return _fullImage;
}

- (BOOL)isFullImageFault
{
    return (_fullImage == nil);
}

- (BOOL)isThumbnailFault
{
    return (_thumbnail == nil);
}

#pragma mark - private functions

- (void)loadFullImageFromRemoteURL
{
    NSData *imageData = [NSData dataWithContentsOfURL:self.remoteURL];
    self.fullImage = [UIImage imageWithData:imageData];
}

- (void)loadThumbnailFromRemoteURL
{
    if (!self.fullImage) {
        [self loadFullImageFromRemoteURL];
    }
}


@end
