//
//  DFPhotoCollection.m
//  Duffy
//
//  Created by Henry Bridge on 3/19/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotoCollection.h"
#import "DFPhoto.h"

@interface DFPhotoCollection() {
    NSMutableSet *photosSet;
    NSMutableArray *photosByDate;
    NSMutableSet *photoAssetURLSet;
    NSMutableArray *objectIDsByDate;
}
@end


@implementation DFPhotoCollection

- (instancetype)init
{
    self = [super init];
    if (self) {
        photosSet = [[NSMutableSet alloc] init];
        photosByDate = [[NSMutableArray alloc] init];
        photoAssetURLSet = [[NSMutableSet alloc] init];
        objectIDsByDate = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithPhotos:(NSArray *)photos {
    self = [self init];
    if (self) {
        [self addPhotos:photos];
    }
    return self;
}

- (void)addPhotos:(NSArray *)newPhotos
{
    for (DFPhoto *newPhoto in newPhotos) {
        if ([self.photoSet containsObject:newPhoto]) continue;
        
        [photosSet addObject:newPhoto];
        if (![photoAssetURLSet containsObject:newPhoto.asset.canonicalURL]) {
            [photoAssetURLSet addObject:newPhoto.asset.canonicalURL];
        } else {
            DDLogError(@"Error, adding another DFPhoto with the same universal ID as another in the set");
        }

        NSUInteger insertIndex = [photosByDate indexOfObject:newPhoto
                      inSortedRange:(NSRange){0, photosByDate.count}
                            options:NSBinarySearchingInsertionIndex
                    usingComparator:^NSComparisonResult(DFPhoto *photo1, DFPhoto *photo2) {
                        return [photo1.creationDate compare:photo2.creationDate];
                    }];
        [photosByDate insertObject:newPhoto atIndex:insertIndex];
        [objectIDsByDate insertObject:newPhoto.objectID atIndex:insertIndex];
    }
}



- (NSSet *)photoSet
{
    return photosSet;
}

- (NSArray *)photosByDateAscending:(BOOL)ascending
{
    if (ascending)
        return photosByDate;
    else
        return [[photosByDate reverseObjectEnumerator] allObjects];
}

- (NSArray *)objectIDsByDateAscending:(BOOL)ascending
{
    if (ascending)
        return objectIDsByDate;
    else
        return [[objectIDsByDate reverseObjectEnumerator] allObjects];
}

- (NSSet *)photoURLSet
{
    return photoAssetURLSet;
}

- (BOOL)containsPhotoWithAssetURL:(NSString *)assetURLString
{
    return [photoAssetURLSet containsObject:assetURLString];
}

- (UIImage *)thumbnail
{
  if (!_thumbnail) {
    if (self.photoSet.count < 1) return nil;
    return [[[self photosByDateAscending:YES] firstObject] thumbnail];
  }
  
  return _thumbnail;
}


@end
