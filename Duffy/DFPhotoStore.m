//
//  DFPhotoStore.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoStore.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFPhotoAlbum.h"
#import "DFPhoto.h"

@interface DFPhotoStore()

@property (nonatomic, retain) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, retain) NSMutableArray *cameraRoll;
@property (nonatomic, retain) NSMutableArray *allRegularAlbums;

@end

@implementation DFPhotoStore

static DFPhotoStore *defaultStore;

+ (DFPhotoStore *)sharedStore {
    if (!defaultStore) {
        defaultStore = [[super allocWithZone:nil] init];
    }
    return defaultStore;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self sharedStore];
}


- (id)init
{
    self = [super init];
    if (self) {
        [self loadCameraRoll];
        [self loadPhotoAlbums];
    }
    return self;
}



- (void)loadCameraRoll
{
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
        if(result != NULL) {
            NSLog(@"Adding to Camera Roll asset: %@", result);
            DFPhoto *photo = [[DFPhoto alloc] initWithAsset:result];
            [_cameraRoll addObject:photo];
        } else {
            NSLog(@"All assets in Camera Roll enumerated");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"com.duffysoft.DFAssetsEnumerated" object:self];
        }
    };
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) {
    	if(group != nil) {
            NSLog(@"Enumerating %d assets in: %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
    		[group enumerateAssetsUsingBlock:assetEnumerator];
    	}
    };
    
    _assetsLibrary = [[ALAssetsLibrary alloc] init];
    
    _cameraRoll = [[NSMutableArray alloc] init];
    
    _allRegularAlbums = [[NSMutableArray alloc] init];
    
    
    [_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
    					   usingBlock:assetGroupEnumerator
    					 failureBlock: ^(NSError *error) {
    						 NSLog(@"Failure");
    					 }];
    
    
}


- (void)loadPhotoAlbums
{
    
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) =  ^(ALAssetsGroup *group, BOOL *stop) {
    	if(group != nil) {
            NSLog(@"Enumerating %d assets in: %@", (int)[group numberOfAssets], [group valueForProperty:ALAssetsGroupPropertyName]);
            [_allRegularAlbums addObject:[[DFPhotoAlbum alloc] initWithAssetGroup:group]];
    	}
    };
    
    _allRegularAlbums = [[NSMutableArray alloc] init];
    
    
    [_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum
                                  usingBlock:assetGroupEnumerator
                                failureBlock: ^(NSError *error) {
                                    NSLog(@"Failure");
                                }];
}


- (NSArray *)allAlbums
{
    return _allRegularAlbums;
}


- (NSArray *)cameraRoll
{
    return _cameraRoll;
}



@end



