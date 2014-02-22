//
//  DFPhoto.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhoto.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <DropboxSDK/DropboxSDK.h>

@interface DFPhoto()

@property (nonatomic, retain) ALAsset *asset;
@property (nonatomic, retain) NSString *dropboxPath;
@property (nonatomic, retain) DBRestClient *restClient;

@end

@implementation DFPhoto

@synthesize photoName, thumbnail, fullImage;

- (id)initWithAsset:(ALAsset *)asset;
{
    self = [super init];
    if (self) {
        self.asset = asset;
        
    }
    return self;
}

- (id)initWithDropboxPath:(NSString *)path name:(NSString *)name
{
    self = [super init];
    if (self) {
        self.dropboxPath = path;
        self.photoName = name;
    }
    return self;
}
- (void)dealloc
{
    NSLog(@"dfphoto %@ dealloc", self.photoName);
}

- (void)loadThumbnail
{
    if (self.asset) {
        CGImageRef imageRef = [self.asset thumbnail];
        self.thumbnail = [UIImage imageWithCGImage:imageRef];
    } else if (self.dropboxPath) {
        //try to load from cache
        UIImage *cachedImage = [UIImage imageWithContentsOfFile:[[self localThumbnailURL] path]];
        if (cachedImage) {
            self.thumbnail = cachedImage;
        } else {
            [self loadThumbnailFromRemoteURL];
        }
    }
}


- (void)loadFullImage
{
    if (self.asset) {
        CGImageRef imageRef = [[self.asset defaultRepresentation] fullResolutionImage];
        self.fullImage = [UIImage imageWithCGImage:imageRef];
    } else if (self.dropboxPath) {
        [self loadFullImageFromRemoteURL];
    }
}

- (BOOL)isFullImageFault
{
    return (self.fullImage == nil);
}

- (BOOL)isThumbnailFault
{
    return (self.thumbnail == nil);
}

#pragma mark - private functions

- (DBRestClient *)restClient {
    if (!_restClient) {
        _restClient = [[DBRestClient alloc]
                       initWithSession:[DBSession sharedSession]];
        _restClient.delegate = self;
    }
    return _restClient;
}

- (void)loadFullImageFromRemoteURL
{
    [[self restClient] loadFile:self.dropboxPath intoPath:[[self localFullImageURL] path]];
}

static NSString *const thumbnailSize = @"m";

- (void)loadThumbnailFromRemoteURL
{
    [[self restClient] loadThumbnail:self.dropboxPath
                              ofSize:thumbnailSize
                            intoPath:[[self localThumbnailURL] path]];
}

- (NSURL *)localFullImageURL
{
    NSString *fullImageFilename = [NSString stringWithFormat:@"%@.jpg", self.photoName];
    return [[DFPhoto localFullImagesDirectoryURL] URLByAppendingPathComponent:fullImageFilename];
}

- (NSURL *)localThumbnailURL
{
    NSString *thumbnailFilename = [NSString stringWithFormat:@"%@.jpg", self.photoName];
    return [[DFPhoto localThumbnailsDirectoryURL] URLByAppendingPathComponent:thumbnailFilename];
}

+ (NSURL *)localFullImagesDirectoryURL
{
    return [[DFPhoto userLibraryURL] URLByAppendingPathComponent:@"fullsize"];
}

+ (NSURL *)localThumbnailsDirectoryURL
{
    return [[DFPhoto userLibraryURL] URLByAppendingPathComponent:@"thumbnails"];
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



#pragma mark - Dropbox callbacks

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath
       contentType:(NSString*)contentType metadata:(DBMetadata*)metadata {
    NSLog(@"File loaded into path: %@", localPath);
    
    if ([localPath isEqualToString:[[self localFullImageURL] path]]){
        self.fullImage = [UIImage imageWithContentsOfFile:localPath];
    }
    
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    NSLog(@"There was an error loading the file - %@", error);
}

- (void)restClient:(DBRestClient *)client loadedThumbnail:(NSString *)localPath metadata:(DBMetadata *)metadata
{
    self.thumbnail = [UIImage imageWithContentsOfFile:localPath];
}

@end
