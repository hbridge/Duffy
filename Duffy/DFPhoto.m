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
@property (nonatomic, retain) NSString *remotePath;
@property (nonatomic, retain) DBRestClient *restClient;

@end

@implementation DFPhoto

@synthesize photoName, thumbnail, fullImage;

- (id)initWithAsset:(ALAsset *)asset;
{
    self = [super init];
    if (self) {
        self.asset = asset;
    }
    return self;
}

- (void)loadThumbnail
{
    if (self.asset) {
        CGImageRef imageRef = [self.asset thumbnail];
        self.thumbnail = [UIImage imageWithCGImage:imageRef];
    } 
}

- (void)loadFullImage
{
    if (self.asset) {
        CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
        self.fullImage = [UIImage imageWithCGImage:imageRef];
    }
}

- (BOOL)isFullImageFault
{
    return (self.fullImage == nil);
}

- (BOOL)isThumbnailFault
{
    return (self.thumbnail == nil);
}


#pragma mark - File Paths


- (NSURL *)localFullImageURL
{
    NSString *fullImageFilename = [NSString stringWithFormat:@"%@.jpg", self.photoName];
    return [[DFPhoto localFullImagesDirectoryURL] URLByAppendingPathComponent:fullImageFilename];
}

- (NSURL *)localThumbnailURL
{
    NSString *thumbnailFilename = [NSString stringWithFormat:@"%@.jpg", self.photoName];
    return [[DFPhoto localThumbnailsDirectoryURL] URLByAppendingPathComponent:thumbnailFilename];
}

+ (NSURL *)localFullImagesDirectoryURL
{
    return [[DFPhoto userLibraryURL] URLByAppendingPathComponent:@"fullsize"];
}

+ (NSURL *)localThumbnailsDirectoryURL
{
    return [[DFPhoto userLibraryURL] URLByAppendingPathComponent:@"thumbnails"];
}


+ (NSURL *)userLibraryURL
{
    NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    
    if ([paths count] > 0)
    {
        return [paths objectAtIndex:0];
    }
    return nil;
}

@end
