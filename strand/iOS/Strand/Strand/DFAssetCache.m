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
@property (readonly, atomic, retain) NSLock *lock;

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
    _lock = [NSLock new];
  }
  return self;
}

- (PHAsset *)assetForLocalIdentifier:(NSString *)localIdentifier
{
  if (!localIdentifier){
    DDLogWarn(@"%@ assetForLocalIdentifier: localIdentifier nil", self.class);
    return nil;
  }
  PHAsset *asset = [self threadSafeGetDict:self.idsToPHAssets key:localIdentifier];
  if (!asset) {
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[localIdentifier]
                                                                  options:nil];
    if (fetchResult.count > 0) {
      asset = fetchResult.firstObject;
      [self threadSafeSetDit:self.idsToPHAssets value:asset forKey:localIdentifier];
    }
  }
  return asset;
}

- (void)setAsset:(PHAsset *)asset forIdentifier:(NSString *)identifier
{
  if (!identifier || !asset){
    DDLogWarn(@"%@ warning setAsset:%@ forLocalIdentifier:%@", self.class, asset, identifier);
    return;
  }
  
  [self threadSafeSetDit:self.idsToPHAssets value:asset forKey:identifier];
}

-(void)threadSafeSetDit:(NSMutableDictionary *)dict value:(id)value forKey:(id)key
{
  if ([self.lock tryLock]) {
    dict[key] = value;
    [self.lock unlock];
  } else if ([NSThread currentThread] != [NSThread mainThread]) {
    [self.lock lock];
    dict[key] = value;
    [self.lock unlock];
  }
}

- (id)threadSafeGetDict:(NSDictionary *)dict key:(id)key
{
  id returnVal = nil;
  if ([self.lock tryLock]) {
    returnVal = dict[key];
    [self.lock unlock];
  } else if ([NSThread currentThread] != [NSThread mainThread]) {
    [self.lock lock];
    returnVal = dict[key];
    [self.lock unlock];
  }

  return returnVal;
}

- (void)setALAsset:(ALAsset *)asset forURL:(NSURL *)url
{
  if (!url || !asset){
    DDLogWarn(@"%@ warning setALAsset:%@ forLocalIdentifier:%@", self.class, asset, url);
    return;
  }
 
  [self threadSafeSetDit:self.URLsToALAssets value:asset forKey:url];
}

- (ALAsset *)assetForURL:(NSURL *)url
{
  return [self threadSafeGetDict:self.URLsToALAssets key:url];
}


@end
