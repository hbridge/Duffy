//
//  DFPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "DFTypedefs.h"


@class ALAsset;

@interface DFPhoto : NSManagedObject

+ (NSURL *)localFullImagesDirectoryURL;
+ (NSURL *)localThumbnailsDirectoryURL;

typedef enum {
  DFFaceFeatureDetectionNone = 0,
  DFFaceFeatureDetectioniOSLowQuality  = 1 << 0,
  DFFaceFeatureDetectioniOSHighQuality = 1 << 1,
} DFFaceFeatureDetectionSources;

// stored properties
@property (nonatomic, retain) NSString *alAssetURLString;
@property (nonatomic) UInt64 userID;
@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, retain) NSData *creationHashData; // stored when the DFPhoto is first created so it can be compared later
@property (nonatomic, retain) NSSet *faceFeatures;
@property (nonatomic) UInt16 faceFeatureSources;
@property (nonatomic) BOOL hasLocation;
@property (nonatomic, retain) CLPlacemark *placemark;
@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic, retain) NSDate *upload157Date;
@property (nonatomic, retain) NSDate *upload569Date;


// fetched (not stored in Core Data DB) properties
@property (readonly, nonatomic, retain) NSData *currentHashData; // generated on the fly from the underlying ALAsset
@property (readonly, nonatomic, retain) NSString *creationHashString;
@property (readonly, nonatomic, retain) NSString *localFilename;
@property (readonly, nonatomic, retain) CLLocation *location;
@property (readonly, nonatomic, retain) NSDictionary *metadataDictionary;


typedef void (^DFPhotoReverseGeocodeCompletionBlock)(NSDictionary *locationDict);
- (void)fetchReverseGeocodeDictionary:(DFPhotoReverseGeocodeCompletionBlock)completionBlock;

// Create a new DFPhoto in a context
+ (DFPhoto *)insertNewDFPhotoForALAsset:(ALAsset *)asset
                           withHashData:(NSData *)hashData
                          photoTimeZone:(NSTimeZone *)timeZone
                              inContext:(NSManagedObjectContext *)context;

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

// Access to data
- (NSData *)thumbnailJPEGData;
- (NSData *)scaledJPEGDataWithSmallerDimension:(CGFloat)length compressionQuality:(float)quality;
- (NSData *)scaledJPEGDataResizedToFitSize:(CGSize)size compressionQuality:(float)quality;



// Use these to access image data Asynchronously if accessing it will be slow
// Note that the created CGImage must be released by the caller to prevent memory leaks

typedef void (^DFPhotoLoadUIImageSuccessBlock)(UIImage *image);
typedef void (^DFPhotoLoadFailureBlock)(NSError *error);

- (void)loadUIImageForFullImage:(DFPhotoLoadUIImageSuccessBlock)successBlock
                   failureBlock:(DFPhotoLoadFailureBlock)failureBlock;
- (void)loadUIImageForThumbnail:(DFPhotoLoadUIImageSuccessBlock)successBlock
                   failureBlock:(DFPhotoLoadFailureBlock)failureBlock;




@end
