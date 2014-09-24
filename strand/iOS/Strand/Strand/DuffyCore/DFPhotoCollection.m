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
  NSMutableSet *photoIDs;
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
      photoIDs = [[NSMutableSet alloc] init];
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
    NSUInteger insertIndex = [photosByDate indexOfObject:newPhoto
                                           inSortedRange:(NSRange){0, photosByDate.count}
                                                 options:NSBinarySearchingInsertionIndex
                                         usingComparator:^NSComparisonResult(DFPhoto *photo1, DFPhoto *photo2) {
                                           return [photo1.utcCreationDate compare:photo2.utcCreationDate];
                                         }];
    [photosByDate insertObject:newPhoto atIndex:insertIndex];
    [objectIDsByDate insertObject:newPhoto.objectID atIndex:insertIndex];
    [photoIDs addObject:@(newPhoto.photoID)];
    [photoAssetURLSet addObject:newPhoto.asset.canonicalURL];
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

- (NSSet *)photoIDSet
{
  return photoIDs;
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
