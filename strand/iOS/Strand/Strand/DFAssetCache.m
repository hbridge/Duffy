//
//  DFPHAssetCache.m
//  Strand
//
//  Created by Henry Bridge on 9/22/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAssetCache.h"

@interface DFAssetCache()

@property (readonly, atomic, retain) NSMutableDictionary *idsToPHAssets;
@property (readonly, atomic, retain) NSMutableDictionary *URLsToALAssets;

@end

@implementation DFAssetCache

static DFAssetCache *defaultCache;
+ (DFAssetCache *)sharedCache
{
  static dispatch_once_t onceToken;
  
  if (!defaultCache) {
    dispatch_once(&onceToken, ^{
      defaultCache = [[DFAssetCache alloc] init];
    });
  }
  return defaultCache;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _idsToPHAssets = [NSMutableDictionary new];
    _URLsToALAssets = [NSMutableDictionary new];
  }
  return self;
}

- (PHAsset *)assetForLocalIdentifier:(NSString *)localIdentifier
{
  if (!localIdentifier){
    DDLogWarn(@"%@ assetForLocalIdentifier: localIdentifier nil", self.class);
    return nil;
  }
  PHAsset *asset = self.idsToPHAssets[localIdentifier];
  if (!asset) {
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier]
                                                                  options:nil];
    if (fetchResult.count > 0) {
      asset = fetchResult.firstObject;
      self.idsToPHAssets[localIdentifier] = asset;
    }
  }
  return asset;
}

- (void)refresh
{
  [self.idsToPHAssets removeAllObjects];
  
  PHFetchResult *allMomentsList = [PHCollectionList
                                   fetchMomentListsWithSubtype:PHCollectionListSubtypeMomentListCluster
                                   options:nil];
  for (PHCollectionList *momentList in allMomentsList) {
    PHFetchResult *collections = [PHCollection fetchCollectionsInCollectionList:momentList
                                                                        options:nil];
    for (PHAssetCollection *assetCollection in collections) {
      PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:assetCollection options:nil];
      for (PHAsset *asset in assets) {
        self.idsToPHAssets[asset.localIdentifier] = asset;
      }
    }
  }
}

- (void)setAsset:(PHAsset *)asset forIdentifier:(NSString *)identifier
{
  if (!identifier || !asset){
    DDLogWarn(@"%@ warning setAsset:%@ forLocalIdentifier:%@", self.class, asset, identifier);
  }
  self.idsToPHAssets[identifier] = asset;
}



- (void)setALAsset:(ALAsset *)asset forURL:(NSURL *)url
{
  if (!url || !asset){
    DDLogWarn(@"%@ warning setALAsset:%@ forLocalIdentifier:%@", self.class, asset, url);
  }
  self.URLsToALAssets[url] = asset;
}

- (ALAsset *)assetForURL:(NSURL *)url
{
  return self.URLsToALAssets[url];
}


@end
