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
#import "ThirdParty/UIImage-Categories/UIImage+Resize.h"

@interface DFPhoto()

@property (nonatomic, retain) ALAsset *asset;

@end

@implementation DFPhoto

@synthesize thumbnail;
@synthesize fullImage;
@synthesize asset = _asset;

@dynamic alAssetURLString, universalIDString, uploadDate, creationDate;


- (UIImage *)thumbnail
{
    UIImage __block *loadedThumbnail;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    // Synchronously load the thunbnail
    // must dispatch this off the main thread or it will deadlock!
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self createCGImageForThumbnail:^(CGImageRef imageRef) {
            loadedThumbnail = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
            dispatch_semaphore_signal(sema);
        } failureBlock:^(NSError *error) {
            dispatch_semaphore_signal(sema);
        }];
    });

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return  loadedThumbnail;
}

- (UIImage *)fullImage
{
    UIImage __block *loadedFullImage;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    // Synchronously load the thunbnail
    // must dispatch this off the main thread or it will deadlock!
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self createCGImageForFullImage:^(CGImageRef imageRef) {
            loadedFullImage = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
            dispatch_semaphore_signal(sema);
        } failureBlock:^(NSError *error) {
            dispatch_semaphore_signal(sema);
        }];
    });
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return loadedFullImage;
}

- (UIImage *)imageResizedToFitSize:(CGSize)size
{
    UIImage *resizedImage = [self.fullImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit
                                                                 bounds:size
                                                   interpolationQuality:kCGInterpolationHigh];
    return resizedImage;
}

- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length
{
    return [self.fullImage resizedImageWithSmallerDimensionScaledToLength:length interpolationQuality:kCGInterpolationHigh];
}


- (void)createCGImageForThumbnail:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock
{
    if (self.asset) {
        CGImageRef imageRef = [self.asset thumbnail];
        CGImageRetain(imageRef);
        successBlock(imageRef);
    } else {
        failureBlock([NSError errorWithDomain:@"" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
    }
    
}

- (void)createCGImageForFullImage:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock
{
    if (self.asset) {
        CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
        CGImageRetain(imageRef);
        successBlock(imageRef);
    } else {
        failureBlock([NSError errorWithDomain:@"" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
    }
}


- (ALAsset *)asset
{
    if (!_asset) {
        NSURL *asseturl = [NSURL URLWithString:self.alAssetURLString];
        ALAssetsLibrary *assetsLibrary = [[DFPhotoStore sharedStore] assetsLibrary];
        
        
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        // must dispatch this off the main thread or it will deadlock!
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [assetsLibrary assetForURL:asseturl resultBlock:^(ALAsset *asset) {
                _asset = asset;
                dispatch_semaphore_signal(sema);
            } failureBlock:^(NSError *error) {
                dispatch_semaphore_signal(sema);
            }];
        });
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    
    return _asset;
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
