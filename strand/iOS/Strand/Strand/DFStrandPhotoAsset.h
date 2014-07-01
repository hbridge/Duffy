//
//  DFStrandPhotoAsset.h
//  Strand
//
//  Created by Henry Bridge on 6/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoAsset.h"
#import "DFPhoto.h"

@interface DFStrandPhotoAsset : DFPhotoAsset

@property (nonatomic, retain) NSString * localURLString;
@property (nonatomic) UInt64 photoID;
@property (nonatomic, retain) id storedMetadata;
@property (nonatomic, retain) id storedLocation;
@property (nonatomic, retain) NSDate *creationDate;

+ (DFStrandPhotoAsset *)createAssetForImageData:(NSData *)imageData
                                        photoID:(DFPhotoIDType)photoID
                                       metadata:(NSDictionary *)metadata
                                       location:(CLLocation *)location
                                   creationDate:(NSDate *)creationDate
                                      inContext:(NSManagedObjectContext *)context;




@end
