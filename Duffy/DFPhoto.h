//
//  DFPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>


@class ALAsset;

@interface DFPhoto : NSManagedObject

+ (NSURL *)localFullImagesDirectoryURL;
+ (NSURL *)localThumbnailsDirectoryURL;

@property (nonatomic, retain) NSString *alAssetURLString;
@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, retain) NSString *universalIDString;
@property (nonatomic, retain) NSDate *uploadDate;

// fetched accessors
@property (readonly, nonatomic, retain) CLLocation *location;

typedef void (^DFPhotoReverseGeocodeCompletionBlock)(NSDictionary *locationDict);
- (void)fetchReverseGeocodeDictionary:(DFPhotoReverseGeocodeCompletionBlock)completionBlock;


// Get a DF Photo instance from its URL
+ (DFPhoto *)photoWithURL:(NSString *)url inContext:(NSManagedObjectContext *)managedObjectContext;

// Access to the images
// Will block if the image needs to be loaded from somewhere.  Access on the main thread should
// Ideally be done with createCGImage calls
@property (readonly, nonatomic, retain) UIImage *fullImage;
@property (readonly, nonatomic, retain) UIImage *thumbnail; // 157x157 thumbnail

// access the image sized to a specific size
- (UIImage *)imageResizedToFitSize:(CGSize)size;
- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length;

// Use these to access image data Asynchronously if accessing it will be slow
// Note that the created CGImage must be released by the caller to prevent memory leaks

typedef void (^DFPhotoLoadSuccessBlock)(CGImageRef imageRef);
typedef void (^DFPhotoLoadFailureBlock)(NSError *error);

- (void)createCGImageForFullImage:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock;
- (void)createCGImageForThumbnail:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock;

// Image attributes

- (NSDictionary *)metadataDictionary;
- (NSString *)localFilename;




@end
