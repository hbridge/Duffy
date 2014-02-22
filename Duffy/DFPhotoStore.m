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
#import <DropboxSDK/DropboxSDK.h>

@interface DFPhotoStore()

@property (nonatomic, retain) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, retain) NSMutableArray *cameraRoll;
@property (nonatomic, retain) NSMutableDictionary *allDFAlbumsByName;
@property (nonatomic, retain) DBRestClient *restClient;

@end

@implementation DFPhotoStore

NSString *const DFPhotoStoreReadyNotification = @"DFPhotoStoreReadyNotification";

static BOOL const useLocalData = NO;

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
        [self createCacheDirectories];
        if (useLocalData) {
            [self loadCameraRoll];
            [self loadPhotoAlbums];
        } else {
            [self loadCSVDatabase];
        }
    
    }
    return self;
}

- (void)createCacheDirectories
{
    // thumbnails
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *directoriesToCreate = @[[[DFPhoto localThumbnailsDirectoryURL] path],
                                     [[DFPhoto localFullImagesDirectoryURL] path]];
    
    for (NSString *path in directoriesToCreate) {
        if (![fm fileExistsAtPath:path]) {
            NSError *error;
            [fm createDirectoryAtPath:path withIntermediateDirectories:NO
                           attributes:nil
                                error:&error];
            if (error) {
                NSLog(@"Error creating cache directory: %@, error: %@", path, error.description);
                abort();
            }
        }

    }
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
            [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreReadyNotification object:self];
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


- (DBRestClient *)restClient {
    if (!_restClient) {
        _restClient =
        [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    return _restClient;
}


static NSString *databaseRemotePath = @"/database.csv";
static NSString *databaseLocalFilename = @"database.csv";


- (void)loadCSVDatabase
{
    
    [[self restClient] loadFile:databaseRemotePath intoPath:[[self localdatabaseURL] path]];
}

- (void)processCSVDatabase {
    NSStringEncoding encoding;
    NSError *error;
    NSString *dataString = [NSString stringWithContentsOfURL:[self localdatabaseURL] usedEncoding:&encoding error:&error];
    
    _cameraRoll = [[NSMutableArray alloc] init];
    _allDFAlbumsByName = [[NSMutableDictionary alloc] init];
    for (NSString *line in [dataString componentsSeparatedByString:@"\n"])
    {
        // add photo to camera roll
        NSArray *components = [line componentsSeparatedByString:@","];
        NSString *filename = components[0];
        NSString *dropboxPath = [NSString stringWithFormat:@"/%@", filename];
        DFPhoto *photo = [[DFPhoto alloc] initWithDropboxPath:dropboxPath name:[filename stringByDeletingPathExtension]];
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DFPhotoStoreReadyNotification object:self];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath
       contentType:(NSString*)contentType metadata:(DBMetadata*)metadata {
    
    NSLog(@"File loaded into path: %@", localPath);
    if ([localPath isEqualToString:[[self localdatabaseURL] path]]) {
        [self processCSVDatabase];
    }
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    NSLog(@"There was an error loading the file - %@", error);
}


- (NSURL *)localdatabaseURL
{
    return [[DFPhotoStore userLibraryURL] URLByAppendingPathComponent:databaseLocalFilename];
}

+ (NSURL *)userLibraryURL
{
    NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    
    if ([paths count] > 0)
    {
        return [paths objectAtIndex:0];
    }
    return nil;
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



