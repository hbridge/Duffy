//
//  DFPhotoAlbum.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoAlbum.h"
#import <AssetsLibrary/ALAssetsGroup.h>
#import "DFPhoto.h"

@interface DFPhotoAlbum()

@property (nonatomic, retain) NSMutableArray *photos;

@end

@implementation DFPhotoAlbum


@synthesize thumbnail;
@synthesize name;

- (id)initWithAssetGroup:(ALAssetsGroup *)assetGroup
{
    self = [super init];
    if (self) {
        self.thumbnail = [UIImage imageWithCGImage:[assetGroup posterImage]];
        self.name = [assetGroup valueForProperty:ALAssetsGroupPropertyName];
        
        
        _photos = [[NSMutableArray alloc] init];
        // add photos in album to album
        void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
            if(result != NULL) {
                NSLog(@"Adding to %@ asset %@", self.name, result);
                DFPhoto *photo = [[DFPhoto alloc] initWithAsset:result];
                [_photos addObject:photo];
            } else {
                NSLog(@"All assets in group %@ enumerated", self.name);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"com.duffysoft.DFAssetsEnumerated" object:self];
            }
        };
        
        [assetGroup enumerateAssetsUsingBlock:assetEnumerator];
    }
    return self;
}





@end
