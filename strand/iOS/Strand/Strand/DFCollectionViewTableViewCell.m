//
//  DFCollectionViewTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCollectionViewTableViewCell.h"
#import "DFPhotoViewCell.h"

@interface DFCollectionViewTableViewCell()

@property (atomic, retain) NSMutableDictionary *imagesForObjects;

@end

@implementation DFCollectionViewTableViewCell

- (void)awakeFromNib
{
  self.imagesForObjects = [NSMutableDictionary new];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"DFPhotoViewCell"];
  self.collectionView.scrollsToTop = NO;
  self.collectionView.delegate = self;
  self.collectionView.dataSource = self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
  [super setSelected:selected animated:animated];
  
  // Configure the view for the selected state
}

- (void)setObjects:(NSArray *)objects
{
  _objects = objects;
  self.imagesForObjects = [NSMutableDictionary new];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.collectionView reloadData];
  });
}

- (void)setImage:(UIImage *)image forObject:(id)object
{
  if (image) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.imagesForObjects[object] = image;
      [self.collectionView reloadData];
    });
  }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return self.objects.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView
                           dequeueReusableCellWithReuseIdentifier:@"DFPhotoViewCell"
                           forIndexPath:indexPath];
  
  id object = self.objects[indexPath.row];
  cell.imageView.image = self.imagesForObjects[object];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  cell.imageView.backgroundColor = [UIColor grayColor];
  
  return cell;
}

@end
