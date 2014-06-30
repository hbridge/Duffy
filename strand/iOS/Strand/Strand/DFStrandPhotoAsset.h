//
//  DFStrandPhotoAsset.h
//  Strand
//
//  Created by Henry Bridge on 6/30/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoAsset.h"


@interface DFStrandPhotoAsset : DFPhotoAsset

@property (nonatomic, retain) NSString * localURLString;
@property (nonatomic, retain) NSString * remoteURLString;
@property (nonatomic, retain) id metadata;

@end
