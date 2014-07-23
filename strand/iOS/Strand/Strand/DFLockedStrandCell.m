//
//  DFLockedStrandCell.m
//  Strand
//
//  Created by Henry Bridge on 7/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLockedStrandCell.h"
#import "DFPhotoViewCell.h"
#import <GPUImage/GPUImage.h>

@interface DFLockedStrandCell()

@property (nonatomic, retain) NSMutableArray *originalImages;
@property (atomic, retain) NSMutableArray *blurredImages;

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
  self.blurredImages = [NSMutableArray new];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    for (UIImage *image in self.originalImages) {
      UIImage *blurredImage = [DFLockedStrandCell blurryGPUImage:image];
      [self.blurredImages addObject:blurredImage];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.collectionView reloadData];
    });
  });
}

- (void)addImage:(UIImage *)image
{
  [self.originalImages addObject:image];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    UIImage *blurredImage = [DFLockedStrandCell blurryGPUImage:image];
    [self.blurredImages addObject:blurredImage];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.collectionView reloadData];
    });
  });
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return self.blurredImages.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView
                           dequeueReusableCellWithReuseIdentifier:@"cell"
                           forIndexPath:indexPath];
  
  cell.imageView.image = self.blurredImages[indexPath.row];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  cell.imageView.backgroundColor = [UIColor grayColor];
  
  return cell;
}

+ (UIImage *)blurryGPUImage:(UIImage *)image {
  GPUImageGaussianBlurFilter *blurFilter = [GPUImageGaussianBlurFilter new];
  blurFilter.blurRadiusInPixels = 10.0;
  UIImage *result = [blurFilter imageByFilteringImage:image];
  return result;
}



@end
