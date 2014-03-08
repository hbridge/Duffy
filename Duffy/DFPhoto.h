//
//  DFPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DBRestClient.h>

@class ALAsset;

@interface DFPhoto : NSObject <DBRestClientDelegate>

+ (NSURL *)localFullImagesDirectoryURL;
+ (NSURL *)localThumbnailsDirectoryURL;

@property (nonatomic, retain) NSString *photoName;
@property (nonatomic, retain) UIImage *fullImage;
@property (nonatomic, retain) UIImage *thumbnail;

- (id)initWithAsset:(ALAsset *)asset;
- (id)initWithDropboxPath:(NSString *)path name:(NSString *)name;

// use these to determine whether asking for the full image will trigger
// a fault, potentially causing UI slowness
- (BOOL)isFullImageFault;
- (BOOL)isThumbnailFault;

// use these to force the class to cache the image data so it can
// be accessed quickly in the future
- (void)loadFullImage;
- (void)loadThumbnail;




@end
