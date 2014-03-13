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
@synthesize asset = _asset;

@dynamic alAssetURLString, universalIDString, uploadDate;


- (UIImage *)thumbnail
{
    if (_thumbnail) return _thumbnail;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    // Synchronously load the thunbnail
    // must dispatch this off the main thread or it will deadlock!
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loadThumbnailWithSuccessBlock:^(UIImage *image) {
            dispatch_semaphore_signal(sema);
        } failureBlock:^(NSError *error) {
            dispatch_semaphore_signal(sema);
        }];
    });

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return  _thumbnail;
}

- (UIImage *)fullImage
{
    if (_fullImage) return  _fullImage;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    // Synchronously load the thunbnail
    // must dispatch this off the main thread or it will deadlock!
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loadFullImageWithSuccessBlock:^(UIImage *image) {
            dispatch_semaphore_signal(sema);
        } failureBlock:^(NSError *error) {
            dispatch_semaphore_signal(sema);
        }];
    });
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return  _fullImage;
}

- (UIImage *)imageResizedToSize:(CGSize *)size
{
    
    
    return nil;
}


- (void)loadThumbnailWithSuccessBlock:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock
{
    if (self.asset) {
        CGImageRef imageRef = [self.asset thumbnail];
        _thumbnail = [UIImage imageWithCGImage:imageRef];
        successBlock(_thumbnail);
    } else {
        failureBlock([NSError errorWithDomain:@"" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
    }
    
}

- (void)loadFullImageWithSuccessBlock:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock
{
    if (self.asset) {
        CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
        _fullImage = [UIImage imageWithCGImage:imageRef];
        successBlock(_fullImage);
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
