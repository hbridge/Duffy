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
#import "DFSection.h"

@class DFImageDataSource;
@protocol DFImageDataSourceDelegate <NSObject>

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath;
@optional
- (void)didFinishFirstLoadForDatasource:(DFImageDataSource *)datasource;

@end


@interface DFImageDataSource : NSObject <UICollectionViewDataSource>

@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, weak) id<DFImageDataSourceDelegate> imageDataSourceDelegate;
@property (nonatomic, retain) NSArray *sections;
@property (nonatomic) BOOL showActionsBadge;
@property (nonatomic) BOOL showUnreadNotifsCount;

- (instancetype)initWithFeedPhotos:(NSArray *)feedPhotos
                    collectionView:(UICollectionView *)collectionView;
- (instancetype)initWithSections:(NSArray *)sections
                  collectionView:(UICollectionView *)collectionView;
- (instancetype)initWithCollectionFeedObjects:(NSArray *)collectionFeedObjects
                               collectionView:(UICollectionView *)collectionView;

- (NSUInteger)photoCount;
- (void)setFeedPhotos:(NSArray *)feedPhotos;
- (void)setCollectionFeedObjects:(NSArray *)collectionFeedObjects;
- (DFPeanutFeedObject *)feedObjectForIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)feedObjectsForSection:(NSUInteger)section;
- (NSArray *)photosForSection:(NSUInteger)section;


#pragma mark - For use by subclasses only;

- (void)setImageForCell:(DFPhotoViewCell *)cell
            photoObject:(DFPeanutFeedObject *)photoObject
              indexPath:(NSIndexPath *)indexPath;


@end
