//
//  DFPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALAsset;

@interface DFPhoto : NSManagedObject

+ (NSURL *)localFullImagesDirectoryURL;
+ (NSURL *)localThumbnailsDirectoryURL;

@property (nonatomic, retain) NSString *alAssetURLString;
@property (nonatomic, retain) NSString *universalIDString;
@property (nonatomic, retain) NSDate *uploadDate;


// access the actual image
@property (readonly, nonatomic, retain) UIImage *fullImage;

// returns a 157x157 thumbnail
@property (readonly, nonatomic, retain) UIImage *thumbnail;

// access the image sized to a specific size
- (UIImage *)imageResizedToSize:(CGSize *)size;


// use these to determine whether asking for the full image will trigger
// a fault, potentially causing UI slowness
- (BOOL)isFullImageFault;
- (BOOL)isThumbnailFault;

// use these to force the class to cache the image data so it can
// be accessed quickly in the future.  blocks can be used to get callbacks

typedef void (^DFPhotoLoadSuccessBlock)(UIImage *image);
typedef void (^DFPhotoLoadFailureBlock)(NSError *error);

- (void)loadFullImage;
- (void)loadThumbnailWithSuccessBlock:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock;



- (NSString *)localFilename;




@end
