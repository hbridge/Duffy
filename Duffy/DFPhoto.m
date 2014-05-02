//
//  DFPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import "DFPhotoStore.h"
#import "ThirdParty/UIImage-Categories/UIImage+Resize.h"
#import "DFPhotoImageCache.h"
#import "DFDataHasher.h"
#import "DFAnalytics.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFUser.h"


@interface DFPhoto()

@property (nonatomic, retain) ALAsset *asset;

@end

@implementation DFPhoto

@synthesize asset = _asset;

@dynamic alAssetURLString;
@dynamic creationDate;
@dynamic creationHashData;
@dynamic hasLocation;
@dynamic placemark;
@dynamic photoID;
@dynamic upload157Date;
@dynamic upload569Date;
@dynamic userID;

NSString *const DFCameraRollExtraMetadataKey = @"{DFCameraRollExtras}";
NSString *const DFCameraRollCreationDateKey = @"DateTimeCreated";


-(void)awakeFromFetch
{
    // in model v3 we added a bunch of fields, including user id.  if the item doesn't have a user ID, populate these fields
    if (!self.userID) {
        self.userID = [[DFUser currentUser] userID];
        self.hasLocation = ([self.asset valueForProperty:ALAssetPropertyLocation] != nil);
    }
}

+ (DFPhoto *)insertNewDFPhotoForALAsset:(ALAsset *)asset withHashData:(NSData *)hashData inContext:(NSManagedObjectContext *)context
{
    DFPhoto *newPhoto = [NSEntityDescription
                         insertNewObjectForEntityForName:@"DFPhoto"
                         inManagedObjectContext:context];
    newPhoto.alAssetURLString = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
    newPhoto.creationDate = [asset valueForProperty:ALAssetPropertyDate];
    newPhoto.creationHashData = hashData;
    newPhoto.hasLocation = ([asset valueForProperty:ALAssetPropertyLocation] != nil);
    newPhoto.userID = [[DFUser currentUser] userID];
    return newPhoto;
}


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

#pragma mark - Core Data stored accessors


#pragma mark - Fetched propery accessors

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

- (NSString *)creationHashString
{
    return [DFDataHasher hashStringForHashData:self.creationHashData];
}

- (NSDictionary *)metadataDictionary
{
    NSMutableDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:self.asset.defaultRepresentation.metadata];
    NSDictionary *cameraRollMetadata = @{
                                         DFCameraRollCreationDateKey: [self formatCreationDate:self.creationDate],
                                         };
    
    [metadata setObject:cameraRollMetadata forKey:DFCameraRollExtraMetadataKey];
    return metadata;
}

- (NSString *)formatCreationDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [NSDateFormatter EXIFDateFormatter];
    return [dateFormatter stringFromDate:date];
}


- (NSString *)localFilename
{
    ALAssetRepresentation *rep = [self.asset defaultRepresentation];
    NSString *fileName = [rep filename];
    return fileName;
}



#pragma mark - Hashing

- (NSData *)currentHashData
{
    return [DFDataHasher hashDataForALAsset:self.asset];
}



#pragma mark - Location

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
            BOOL possibleThrottle = NO;
            if (error.code == kCLErrorNetwork) possibleThrottle = YES;
            DDLogError(@"fetchReverseGeocodeDict error:%@, Possible rate limit:%@",
                       [error localizedDescription],
                       possibleThrottle ? @"YES" : @"NO");
            [DFAnalytics logMapsServiceErrorWithCode:error.code isPossibleRateLimit:possibleThrottle];
        }
        
        completionBlock(locationDict);
    }];
}

#pragma mark - Image Accessors

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

- (NSData *)thumbnailData
{
    NSMutableData *data = [[NSMutableData alloc] init];
    CGImageDestinationRef destinationRef =
    
    CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,
                                    /* file type */ kUTTypeJPEG,
                                    /* number of images */ 1,
                                    /* reserved */ NULL);
    
    NSDictionary *properties = @{
                                 (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(0.7)
                                 };
    
    CGImageDestinationSetProperties(destinationRef,
                                    (__bridge CFDictionaryRef)properties);
    CGImageDestinationAddImage(destinationRef,
                               /* image */ self.thumbnail.CGImage,
                               /* properties */ NULL);
    CGImageDestinationFinalize(destinationRef);
    CFRelease(destinationRef);
    
    return data;
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

- (UIImage *)highResolutionImage
{
    if (self.asset) {
        @autoreleasepool {
            UIImage *image = [self thumbnailForAsset:self.asset maxPixelSize:2048];
            return image;
        }
    } else {
        DDLogError(@"Could not get asset for photo: %@", self.description);
    }
    
    return nil;
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
    UIImage *resizedImage = [self thumbnailForAsset:self.asset maxPixelSize:MAX(size.height, size.width)];
    return resizedImage;
}

- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length
{
    CGSize originalSize = self.asset.defaultRepresentation.dimensions;
    CGSize newSize;
    if (originalSize.height < originalSize.width) {
        CGFloat scaleFactor = length/originalSize.height;
        newSize = CGSizeMake(ceil(originalSize.width * scaleFactor), length);
    } else {
        CGFloat scaleFactor = length/originalSize.width;
        newSize = CGSizeMake(length, ceil(originalSize.height * scaleFactor));
    }
    
    return [self imageResizedToFitSize:newSize];
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
        @autoreleasepool {
            CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
            UIImage *image = [UIImage imageWithCGImage:imageRef
                                                 scale:self.asset.defaultRepresentation.scale
                                           orientation:(UIImageOrientation)self.asset.defaultRepresentation.orientation];
            [[DFPhotoImageCache sharedCache] setFullResolutionImage:image
                                              forPhotoWithURLString:self.alAssetURLString];
            successBlock(image);
        }
    } else {
        failureBlock([NSError errorWithDomain:@"" code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not get asset for photo."}]);
    }
}

// Helper methods for thumbnailForAsset:maxPixelSize:
static size_t getAssetBytesCallback(void *info, void *buffer, off_t position, size_t count) {
    ALAssetRepresentation *rep = (__bridge id)info;
    
    NSError *error = nil;
    size_t countRead = [rep getBytes:(uint8_t *)buffer fromOffset:position length:count error:&error];
    
    if (countRead == 0 && error) {
        // We have no way of passing this info back to the caller, so we log it, at least.
        NSLog(@"thumbnailForAsset:maxPixelSize: got an error reading an asset: %@", error);
    }
    
    return countRead;
}

static void releaseAssetCallback(void *info) {
    // The info here is an ALAssetRepresentation which we CFRetain in thumbnailForAsset:maxPixelSize:.
    // This release balances that retain.
    CFRelease(info);
}

// Returns a UIImage for the given asset, with size length at most the passed size.
// The resulting UIImage will be already rotated to UIImageOrientationUp, so its CGImageRef
// can be used directly without additional rotation handling.
// This is done synchronously, so you should call this method on a background queue/thread.
- (UIImage *)thumbnailForAsset:(ALAsset *)asset maxPixelSize:(NSUInteger)size {
    NSParameterAssert(asset != nil);
    NSParameterAssert(size > 0);
    
    ALAssetRepresentation *rep = [asset defaultRepresentation];
    
    CGDataProviderDirectCallbacks callbacks = {
        .version = 0,
        .getBytePointer = NULL,
        .releaseBytePointer = NULL,
        .getBytesAtPosition = getAssetBytesCallback,
        .releaseInfo = releaseAssetCallback,
    };
    
    CGDataProviderRef provider = CGDataProviderCreateDirect((void *)CFBridgingRetain(rep), [rep size], &callbacks);
    CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, NULL);
    
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source,
                                                              0,
                                                              (__bridge CFDictionaryRef) @{
                                                                                           (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                                                           (NSString *)kCGImageSourceThumbnailMaxPixelSize : [NSNumber numberWithUnsignedInteger:size],
                                                                                           (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                                                           });
    CFRelease(source);
    CFRelease(provider);
    
    if (!imageRef) {
        return nil;
    }
    
    UIImage *toReturn = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
    
    return toReturn;
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
