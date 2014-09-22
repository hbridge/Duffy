//
//  DFPHAssetCache.h
//  Strand
//
//  Created by Henry Bridge on 9/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@interface DFPHAssetCache : NSObject

+ (DFPHAssetCache *)sharedCache;
- (PHAsset *)assetForLocalIdentifier:(NSString *)localIdentifier;
- (void)setAsset:(PHAsset *)asset forIdentifier:(NSString *)identifier;

@end
