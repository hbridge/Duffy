//
//  DFPhotoAsset.m
//  Strand
//
//  Created by Henry Bridge on 6/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoAsset.h"

const CGFloat DFPhotoAssetDefaultThumbnailSize = 157.0;
const CGFloat DFPhotoAssetHighQualitySize = 2048.0; // max texture
const CGFloat DFPhotoAssetDefaultJPEGCompressionQuality = 0.8;

@implementation DFPhotoAsset

@dynamic photo;
@dynamic storedMetadata;

#pragma mark Methods to Override from here down

- (NSMutableDictionary *)metadata
{
  return self.storedMetadata;
}


@end
