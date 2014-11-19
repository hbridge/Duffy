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

@interface DFPhoto : NSManagedObject

// stored properties
@property (nonatomic) DFUserIDType userID;
@property (nonatomic) DFPhotoIDType photoID;
@property (nonatomic, retain) DFPhotoAsset *asset;

@property (nonatomic, retain) NSNumber *faceDetectPass;
@property (nonatomic, retain) NSNumber *faceDetectPassUploaded;
@property (nonatomic, retain) NSSet *faceFeatures;
@property (nonatomic, retain) NSDate *utcCreationDate;
@property (nonatomic, retain) NSDate *uploadThumbDate;
@property (nonatomic, retain) NSDate *uploadLargeDate;
@property (nonatomic) BOOL isUploadProcessed;
@property (nonatomic) BOOL shouldUploadImage;
@property (nonatomic, retain) NSString *sourceString;

typedef void (^DFPhotoReverseGeocodeCompletionBlock)(NSDictionary *locationDict);
- (void)fetchReverseGeocodeDictionary:(DFPhotoReverseGeocodeCompletionBlock)completionBlock;

// Create a new DFPhoto in a context
+ (DFPhoto *)createWithAsset:(DFPhotoAsset *)asset
                      userID:(DFUserIDType)userID
               savedFromSwap:(BOOL)savedFromSwap
                   inContext:(NSManagedObjectContext *)context;

- (BOOL)isDeleteableByUser:(DFUserIDType)userID;

@end
