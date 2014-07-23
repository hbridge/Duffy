//
//  DFLockedStrandCell.m
//  Strand
//
//  Created by Henry Bridge on 7/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLockedStrandCell.h"
#import "DFPhotoViewCell.h"

@interface DFLockedStrandCell()

@property (nonatomic, retain) NSMutableArray *originalImages;
@property (nonatomic, retain) NSMutableArray *blurredImages;

@end

@implementation DFLockedStrandCell

- (void)awakeFromNib
{
  self.images = [NSMutableArray new];
  self.collectionView.delegate = self;
  self.collectionView.dataSource = self;
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
  self.collectionView.backgroundColor = [UIColor clearColor];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
  [super setSelected:selected animated:animated];
  
  // Configure the view for the selected state
}

- (void)setImages:(NSArray *)images
{
  self.originalImages = [images mutableCopy];
  [self.collectionView reloadData];
}

- (void)addImage:(UIImage *)image
{
  [self.originalImages addObject:image];
  [self.collectionView reloadData];
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return self.originalImages.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView
                           dequeueReusableCellWithReuseIdentifier:@"cell"
                           forIndexPath:indexPath];
  
  cell.imageView.image = self.originalImages[indexPath.row];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  cell.imageView.backgroundColor = [UIColor grayColor];
  
  return cell;
}



@end
