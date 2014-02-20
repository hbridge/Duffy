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
@property (nonatomic, retain) NSMutableDictionary *allDFAlbumsByName;

@end

@implementation DFPhotoStore

static BOOL const useLocalData = NO;
static NSURL *photoURLBase;

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
        if (useLocalData) {
            [self loadCameraRoll];
            [self loadPhotoAlbums];
        } else {
            photoURLBase = [NSURL URLWithString:@"https://dl.dropboxusercontent.com/u/45798351/photos/"];
            [self loadCSVDatabase];
        }
    
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
            DFPhotoAlbum *album = [[DFPhotoAlbum alloc] initWithAssetGroup:group];
            _allDFAlbumsByName[album.name] = album;
    	} else {
            NSLog(@"all albums enumerated");
        }
    };
    
    _allDFAlbumsByName = [[NSMutableDictionary alloc] init];
    
    [_assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum
                                  usingBlock:assetGroupEnumerator
                                failureBlock: ^(NSError *error) {
                                    NSLog(@"Failure");
                                }];
}


- (void)loadCSVDatabase
{
    NSURL *dataURL = [[NSBundle mainBundle] URLForResource:@"database" withExtension:@"csv"];
    
    NSStringEncoding encoding;
    NSError *error;
    NSString *dataString = [NSString stringWithContentsOfURL:dataURL usedEncoding:&encoding error:&error];
    
    _cameraRoll = [[NSMutableArray alloc] init];
    _allDFAlbumsByName = [[NSMutableDictionary alloc] init];
    for (NSString *line in [dataString componentsSeparatedByString:@"\n"])
    {
        // add photo to camera roll
        NSArray *components = [line componentsSeparatedByString:@","];
        NSString *filename = components[0];
        DFPhoto *photo = [[DFPhoto alloc] initWithURL:[photoURLBase URLByAppendingPathComponent:filename]];
        [_cameraRoll addObject:photo];
        
        // add photo to album and create if necessary
        NSRange categoryConfidenceRange;
        categoryConfidenceRange.location = 1;
        categoryConfidenceRange.length = components.count - 1;
        for (NSString *categoryConfidenceString in [components subarrayWithRange:categoryConfidenceRange]) {
            NSString *trimmedString = [categoryConfidenceString stringByTrimmingCharactersInSet:
                                                                  [NSCharacterSet whitespaceCharacterSet]];
            NSString *categoryName = [[trimmedString componentsSeparatedByString:@" "] firstObject];
            if (![categoryName isEqualToString:@""]) {
                DFPhotoAlbum *categoryAlbum = _allDFAlbumsByName[categoryName];
                if (!categoryAlbum) {
                    categoryAlbum = [[DFPhotoAlbum alloc] init];
                    categoryAlbum.name = categoryName;
                    _allDFAlbumsByName[categoryName] = categoryAlbum;
                }
                [categoryAlbum addPhotosObject:photo];
            }
        }
        
    }
    
}

- (NSArray *)allAlbumsByName
{
    NSArray *keys = [_allDFAlbumsByName keysSortedByValueUsingComparator:
        ^NSComparisonResult(DFPhotoAlbum *album1, DFPhotoAlbum *album2) {
            return [album1.name compare:album2.name];
    }];
    return [_allDFAlbumsByName objectsForKeys:keys notFoundMarker:@"not found"];
}

- (NSArray *)allAlbumsByCount
{
    // get the keys in reverse order
    NSArray *keys = [_allDFAlbumsByName keysSortedByValueUsingComparator:
                     ^NSComparisonResult(DFPhotoAlbum *album1, DFPhotoAlbum *album2) {
                         if (album1.photos.count < album2.photos.count) {
                             return NSOrderedDescending;
                         } else if (album1.photos.count > album2.photos.count) {
                             return NSOrderedAscending;
                         } else {
                             return NSOrderedSame;
                         }
                     }];

    return [_allDFAlbumsByName objectsForKeys:keys notFoundMarker:@"not found"];
}


- (NSArray *)cameraRoll
{
    return _cameraRoll;
}



@end



