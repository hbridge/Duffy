//
//  DFImageDataSource.h
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFImageDataSource : NSObject <UICollectionViewDataSource>

typedef enum {
  DFImageDataSourceModeRemote,
  DFImageDataSourceModeLocal,
} DFImageDataSourceMode;

@property (nonatomic, retain) NSDictionary *indexPathsToObjects;
@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic) DFImageDataSourceMode sourceMode;
@property (nonatomic) DFImageType imageType;

- (instancetype)initWithFeedPhotos:(NSArray *)feedPhotos
                    collectionView:(UICollectionView *)collectionView
                        sourceMode:(DFImageDataSourceMode)sourceMode
                         imageType:(DFImageType)imageType;
@end
