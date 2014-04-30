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
@property (readonly, nonatomic, retain) NSData *currentHashData; // generated on the fly from the underlying ALAsset
@property (nonatomic, retain) NSData *creationHashData; // stored when the DFPhoto is first created so it can be compared later
@property (readonly, nonatomic, retain) NSDictionary *metadataDictionary;
@property (readonly, nonatomic, retain) NSString *localFilename;

// fetched accessors
@property (readonly, nonatomic, retain) CLLocation *location;

typedef void (^DFPhotoReverseGeocodeCompletionBlock)(NSDictionary *locationDict);
- (void)fetchReverseGeocodeDictionary:(DFPhotoReverseGeocodeCompletionBlock)completionBlock;


// Get a DF Photo instance from its URL
+ (DFPhoto *)photoWithURL:(NSString *)url inContext:(NSManagedObjectContext *)managedObjectContext;

// Access to the images
// Will block if the image needs to be loaded from somewhere.  Access on the main thread should
// Ideally be done with createCGImage calls
@property (readonly, nonatomic, retain) UIImage *fullResolutionImage;
@property (readonly, nonatomic, retain) UIImage *thumbnail; // 157x157 thumbnail
@property (readonly, nonatomic, retain) UIImage *highResolutionImage; //max 2048x2048, aspect fit
@property (readonly, nonatomic, retain) UIImage *fullScreenImage;


// access the image sized to a specific size
- (UIImage *)imageResizedToFitSize:(CGSize)size;
- (UIImage *)scaledImageWithSmallerDimension:(CGFloat)length;

// Use these to access image data Asynchronously if accessing it will be slow
// Note that the created CGImage must be released by the caller to prevent memory leaks

typedef void (^DFPhotoLoadUIImageSuccessBlock)(UIImage *image);
typedef void (^DFPhotoLoadFailureBlock)(NSError *error);

- (void)loadUIImageForFullImage:(DFPhotoLoadUIImageSuccessBlock)successBlock
                   failureBlock:(DFPhotoLoadFailureBlock)failureBlock;
- (void)loadUIImageForThumbnail:(DFPhotoLoadUIImageSuccessBlock)successBlock
                   failureBlock:(DFPhotoLoadFailureBlock)failureBlock;




@end
