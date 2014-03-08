//
//  DFPhotoAlbum.h
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ALAssetsGroup;
@class DFPhoto;

@interface DFPhotoAlbum : NSObject

@property (nonatomic, retain) UIImage *thumbnail;
@property (nonatomic, retain) NSString *name;

- (id)initWithAssetGroup:(ALAssetsGroup *)assetGroup;

- (NSArray *)photos;
- (void)addPhotosObject:(DFPhoto *)object;


@end
