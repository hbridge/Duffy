//
//  DFImageDataSource.h
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"

@protocol DFImageDataSourceSupplementaryViewDelegate <NSObject>

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath;

@end


@interface DFImageDataSource : NSObject <UICollectionViewDataSource>

typedef enum {
  DFImageDataSourceModeRemote,
  DFImageDataSourceModeLocal,
} DFImageDataSourceMode;


@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic) DFImageDataSourceMode sourceMode;
@property (nonatomic) DFImageType imageType;
@property (nonatomic, weak) id<DFImageDataSourceSupplementaryViewDelegate> supplementaryViewDelegate;
@property (nonatomic, retain) NSArray *collectionFeedObjects;

- (instancetype)initWithFeedPhotos:(NSArray *)feedPhotos
                    collectionView:(UICollectionView *)collectionView
                        sourceMode:(DFImageDataSourceMode)sourceMode
                         imageType:(DFImageType)imageType;
- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                               collectionView:(UICollectionView *)collectionView
                                   sourceMode:(DFImageDataSourceMode)sourceMode
                                    imageType:(DFImageType)imageType;

- (void)setFeedPhotos:(NSArray *)feedPhotos;
- (void)setCollectionFeedObjects:(NSArray *)collectionFeedObjects;
- (DFPeanutFeedObject *)feedObjectForIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)feedObjectsForSection:(NSUInteger)section;


#pragma mark - For use by subclasses only;

- (void)setRemotePhotoForCell:(DFPhotoViewCell *)cell
                  photoObject:(DFPeanutFeedObject *)photoObject
                    indexPath:(NSIndexPath *)indexPath;
- (void)setLocalPhotosForCell:(DFPhotoViewCell *)cell
                  photoObject:(DFPeanutFeedObject *)photoObject
                    indexPath:(NSIndexPath *)indexPath;


@end
