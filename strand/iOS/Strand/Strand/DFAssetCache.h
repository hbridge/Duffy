//
//  DFPHAssetCache.h
//  Strand
//
//  Created by Henry Bridge on 9/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface DFAssetCache : NSObject

+ (DFAssetCache *)sharedCache;
- (PHAsset *)assetForLocalIdentifier:(NSString *)localIdentifier;
- (void)setAsset:(PHAsset *)asset forIdentifier:(NSString *)identifier;

- (void)setALAsset:(ALAsset *)asset forURL:(NSURL *)url;
- (ALAsset *)assetForURL:(NSURL *)url;

@end
