//
//  DFPHAssetCache.m
//  Strand
//
//  Created by Henry Bridge on 9/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPHAssetCache.h"

@interface DFPHAssetCache()

@property (readonly, atomic, retain) NSMutableDictionary *idsToAssets;

@end

@implementation DFPHAssetCache


static DFPHAssetCache *defaultCache;
+ (DFPHAssetCache *)sharedCache
{
  if (!defaultCache) {
    defaultCache = [[DFPHAssetCache alloc] init];
  }
  return defaultCache;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _idsToAssets = [NSMutableDictionary new];
  }
  return self;
}

- (PHAsset *)assetForLocalIdentifier:(NSString *)localIdentifier
{
  PHAsset *asset = self.idsToAssets[localIdentifier];
  if (!asset) {
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier]
                                                                  options:nil];
    if (fetchResult.count > 0) {
      asset = fetchResult.firstObject;
      self.idsToAssets[localIdentifier] = asset;
    }
  }
  return asset;
}

- (void)refresh
{
  [self.idsToAssets removeAllObjects];
  
  PHFetchResult *allMomentsList = [PHCollectionList
                                   fetchMomentListsWithSubtype:PHCollectionListSubtypeMomentListCluster
                                   options:nil];
  for (PHCollectionList *momentList in allMomentsList) {
    PHFetchResult *collections = [PHCollection fetchCollectionsInCollectionList:momentList
                                                                        options:nil];
    for (PHAssetCollection *assetCollection in collections) {
      PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:assetCollection options:nil];
      for (PHAsset *asset in assets) {
        self.idsToAssets[asset.localIdentifier] = asset;
      }
    }
  }
}

- (void)setAsset:(PHAsset *)asset forIdentifier:(NSString *)identifier
{
  self.idsToAssets[identifier] = asset;
}

@end
