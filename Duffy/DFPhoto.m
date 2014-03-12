//
//  DFPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhotoStore.h"

@interface DFPhoto()

@property (nonatomic, retain) ALAsset *asset;

@end

@implementation DFPhoto

@synthesize thumbnail = _thumbnail;
@synthesize fullImage = _fullImage;
@synthesize asset;

@dynamic alAssetURLString, universalIDString, uploadDate;

- (void)loadThumbnailWithSuccessBlock:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock
{
    if (self.asset) {
        CGImageRef imageRef = [self.asset thumbnail];
        _thumbnail = [UIImage imageWithCGImage:imageRef];
    } else {
        ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
        {
            self.asset = myasset;
            _thumbnail = [UIImage imageWithCGImage:asset.thumbnail];
            successBlock(_thumbnail);
        };
        
        ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
        {
            failureBlock(myerror);
        };
        
        NSURL *asseturl = [NSURL URLWithString:self.alAssetURLString];
        ALAssetsLibrary *assetsLibrary = [[DFPhotoStore sharedStore] assetsLibrary];
        [assetsLibrary assetForURL:asseturl
                       resultBlock:resultblock
                      failureBlock:failureblock];
    }
}

- (void)loadFullImage
{
    if (self.asset) {
        CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
        _thumbnail = [UIImage imageWithCGImage:imageRef];
    }
}


- (UIImage *)imageResizedToSize:(CGSize *)size
{
    
    
    return nil;
}

- (BOOL)isFullImageFault
{
    return (self.fullImage == nil);
}

- (BOOL)isThumbnailFault
{
    return (self.thumbnail == nil);
}

- (NSString *)localFilename
{
    //NSURL *url = [NSURL URLWithString:self.alAssetURLString];
    ALAssetRepresentation *rep = [self.asset defaultRepresentation];
    NSString *fileName = [rep filename];
    return fileName;
}


#pragma mark - File Paths



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
