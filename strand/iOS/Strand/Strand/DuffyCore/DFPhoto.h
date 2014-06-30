//
//  DFPhoto.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "DFPhotoAsset.h"
#import "DFUser.h"

typedef UInt64 DFPhotoIDType;

@interface DFPhoto : NSManagedObject

+ (NSURL *)localFullImagesDirectoryURL;
+ (NSURL *)localThumbnailsDirectoryURL;

// stored properties
@property (nonatomic) UInt64 userID;
@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic, retain) DFPhotoAsset *asset;

@property (nonatomic, retain) NSDate *creationDate;
@property (nonatomic, retain) NSDate *upload157Date;
@property (nonatomic, retain) NSDate *upload569Date;

typedef void (^DFPhotoReverseGeocodeCompletionBlock)(NSDictionary *locationDict);
- (void)fetchReverseGeocodeDictionary:(DFPhotoReverseGeocodeCompletionBlock)completionBlock;

// Create a new DFPhoto in a context
+ (DFPhoto *)createWithAsset:(DFPhotoAsset *)asset
                        userID:(DFUserIDType)userID
                    timeZone:(NSTimeZone *)timeZone
                   inContext:(NSManagedObjectContext *)context;

@end
