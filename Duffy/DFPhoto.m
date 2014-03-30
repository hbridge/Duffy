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
#import "DFPhotoImageCache.h"

@interface DFPhoto()

@property (nonatomic, retain) ALAsset *asset;

@end

@implementation DFPhoto

@synthesize asset = _asset;

@dynamic alAssetURLString, universalIDString, uploadDate, creationDate;


+ (DFPhoto *)photoWithURL:(NSString *)url inContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [[managedObjectContext.persistentStoreCoordinator.managedObjectModel entitiesByName] objectForKey:@"DFPhoto"];
    request.entity = entity;
    
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"alAssetURLString ==[c] %@", url];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *result = [managedObjectContext executeFetchRequest:request error:&error];
    if (!result) {
        [NSException raise:@"Could search for photos."
                    format:@"Error: %@", [error localizedDescription]];
    }
    
    if (result.count < 1) return nil;
    
    return [result firstObject];
}

- (CLLocation *)location
{
    return [self.asset valueForProperty:ALAssetPropertyLocation];
}

- (void)fetchReverseGeocodeDictionary:(DFPhotoReverseGeocodeCompletionBlock)completionBlock
{
    if (self.location == nil) {
        completionBlock(@{});
    }
    
    CLGeocoder *geocoder = [[CLGeocoder alloc]init];
    [geocoder reverseGeocodeLocation:self.location completionHandler:^(NSArray *placemarks, NSError *error) {
        NSDictionary *locationDict = @{};

        if (placemarks.count > 0) {
            CLPlacemark *placemark = placemarks.firstObject;
            locationDict = @{@"address": [NSDictionary dictionaryWithDictionary:placemark.addressDictionary],
                                           @"pois" : [NSArray arrayWithArray:placemark.areasOfInterest]};
        }
        
        if (error) {
            NSLog(@"fetchReverseGeocodeDict error:%@", [error localizedDescription]);
        }
        
        completionBlock(locationDict);
    }];
}

- (UIImage *)thumbnail
{
    UIImage *cachedImage = [[DFPhotoImageCache sharedCache]
                            thumbnailForPhotoWithURLString:self.alAssetURLString];
    if (cachedImage) return cachedImage;
    
    UIImage __block *loadedThumbnail;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    // Synchronously load the thunbnail
    // must dispatch this off the main thread or it will deadlock!
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loadUIImageForThumbnail:^(UIImage *thumbnailImage) {
            loadedThumbnail = thumbnailImage;
            dispatch_semaphore_signal(sema);
        } failureBlock:^(NSError *error) {
            dispatch_semaphore_signal(sema);
        }];
    });

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return  loadedThumbnail;
}

- (UIImage *)fullResolutionImage
{
    UIImage *cachedImage = [[DFPhotoImageCache sharedCache]
                            fullResolutionImageForPhotoWithURLString:self.alAssetURLString];
    if (cachedImage) return cachedImage;
    
   UIImage __block *loadedFullImage;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    // Synchronously load the thunbnail
    // must dispatch this off the main thread or it will deadlock!
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loadUIImageForFullImage:^(UIImage *image) {
            loadedFullImage = image;
            dispatch_semaphore_signal(sema);
        } failureBlock:^(NSError *error) {
            dispatch_semaphore_signal(sema);
        }];
    });
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return loadedFullImage;
}

- (UIImage *)fullScreenImage
{
    UIImage *cachedImage = [[DFPhotoImageCache sharedCache]
                            fullScreenImageForPhotoWithURLString:self.alAssetURLString];
    if (cachedImage) return cachedImage;
    
    CGImageRef imageRef = self.asset.defaultRepresentation.fullScreenImage;
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    [[DFPhotoImageCache sharedCache] setFullScreenImage:image forPhotoWithURLString:self.alAssetURLString];
    
    return image;
}

- (UIImage *)imageResizedToFitSize:(CGSize)size
{
    UIImage *resizedImage = [self.fullResolutionImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit
                                                                 bounds:size
                                                   interpolationQuality:kCGInterpolationHigh];
    return resizedImage;
}

- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length
{
    return [self.fullResolutionImage resizedImageWithSmallerDimensionScaledToLength:length interpolationQuality:kCGInterpolationHigh];
}


- (void)loadUIImageForThumbnail:(DFPhotoLoadUIImageSuccessBlock)successBlock
                   failureBlock:(DFPhotoLoadFailureBlock)failureBlock
{
    UIImage *cachedImage = [[DFPhotoImageCache sharedCache]
                            thumbnailForPhotoWithURLString:self.alAssetURLString];
    if (cachedImage) {
        successBlock(cachedImage);
        return;
    }
    
    if (self.asset) {
        CGImageRef imageRef = [self.asset thumbnail];
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        [[DFPhotoImageCache sharedCache] setThumbnail:image forPhotoWithURLString:self.alAssetURLString];
        successBlock(image);
    } else {
        failureBlock([NSError errorWithDomain:@"" code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
    }
}


- (void)loadUIImageForFullImage:(DFPhotoLoadUIImageSuccessBlock)successBlock
                   failureBlock:(DFPhotoLoadFailureBlock)failureBlock
{
    UIImage *cachedImage = [[DFPhotoImageCache sharedCache]
                            fullResolutionImageForPhotoWithURLString:self.alAssetURLString];
    if (cachedImage) {
        successBlock(cachedImage);
        return;
    }
    
    if (self.asset) {
        CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
        UIImage *image = [UIImage imageWithCGImage:imageRef
                                             scale:self.asset.defaultRepresentation.scale
                                       orientation:(UIImageOrientation)self.asset.defaultRepresentation.orientation];
        [[DFPhotoImageCache sharedCache] setFullResolutionImage:image
                                forPhotoWithURLString:self.alAssetURLString];
        successBlock(image);
    } else {
        failureBlock([NSError errorWithDomain:@"" code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
    }
}


- (CIImage *)CIImageForFullImage
{
    ALAssetRepresentation *rep = [self.asset defaultRepresentation];
    Byte *buffer = (Byte*)malloc((unsigned long)rep.size);
    NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:(unsigned long)rep.size error:nil];
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
    
    
    return [CIImage imageWithData:data];
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


- (NSDictionary *)metadataDictionary
{
    return self.asset.defaultRepresentation.metadata;
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
