//
//  DFUploadingFeedCell.m
//  Strand
//
//  Created by Henry Bridge on 7/28/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFUploadingFeedCell.h"
#import "DFPhotoViewCell.h"

@interface DFUploadingFeedCell()

@property (nonatomic, retain) NSMutableArray *mutableImages;

@end

@implementation DFUploadingFeedCell

- (void)awakeFromNib
{
  self.collectionView.delegate = self;
  self.collectionView.dataSource = self;
  self.collectionView.backgroundColor = [UIColor clearColor];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
  if (!self.mutableImages) self.mutableImages = [NSMutableArray new];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (NSArray *)images
{
  return self.mutableImages;
}

- (void)setImages:(NSArray *)images
{
  _mutableImages = [images mutableCopy];
  [self.collectionView reloadData];
}

- (void)addImage:(UIImage *)image
{
  [self.mutableImages addObject:image];
  [self.collectionView reloadData];
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return self.images.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView
                           dequeueReusableCellWithReuseIdentifier:@"cell"
                           forIndexPath:indexPath];
  
  cell.imageView.image = self.images[indexPath.row];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  cell.imageView.backgroundColor = [UIColor grayColor];
  
  return cell;
}

@end
