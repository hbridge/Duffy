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


// Access to the images
// Will block if the image needs to be loaded from somewhere.  Access on the main thread should be preceeded
// by a check for a fault and a load to prevent unresponsiveness.
@property (readonly, nonatomic, retain) UIImage *fullImage;
// returns a 157x157 thumbnail
@property (readonly, nonatomic, retain) UIImage *thumbnail;

// access the image sized to a specific size
- (UIImage *)imageResizedToFitSize:(CGSize)size;

// use these to force the class to cache the image data so it can
// be accessed quickly in the future.  blocks can be used to get callbacks

typedef void (^DFPhotoLoadSuccessBlock)(CGImageRef imageRef);
typedef void (^DFPhotoLoadFailureBlock)(NSError *error);

- (void)createCGImageForFullImage:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock;
- (void)createCGImageForThumbnail:(DFPhotoLoadSuccessBlock)successBlock failureBlock:(DFPhotoLoadFailureBlock)failureBlock;



- (NSString *)localFilename;




@end
