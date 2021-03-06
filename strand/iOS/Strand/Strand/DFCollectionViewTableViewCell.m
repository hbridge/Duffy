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
@property (nonatomic, retain) NSMutableDictionary *tapHandlers;

@end

@implementation DFCollectionViewTableViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  self.imagesForObjects = [NSMutableDictionary new];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"DFPhotoViewCell"];
  self.collectionView.scrollsToTop = NO;
  self.collectionView.dataSource = self;
  self.collectionView.backgroundColor = [UIColor clearColor];
}

- (void)setObjects:(NSArray *)objects
{
  _objects = objects;
  self.imagesForObjects = [NSMutableDictionary new];
  self.tapHandlers = [NSMutableDictionary new];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.collectionView reloadData];
  });
}

- (void)setImage:(UIImage *)image forObject:(id<NSCopying>)object
{
  if (image) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.imagesForObjects[object] = image;
      [self.collectionView reloadData];
      [self setNeedsLayout];
    });
  } else {
    DDLogVerbose(@"Attempting to set nil image for %@", self.class);
  }
}

- (UIImage *)imageForObject:(id<NSCopying>)object
{
  return self.imagesForObjects[object];
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
  UIImage *image = self.imagesForObjects[object];
  cell.imageView.image = image;
  if (image) {
    [cell.loadingActivityIndicator stopAnimating];
  } else {
    [cell.loadingActivityIndicator startAnimating];
  }
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  cell.imageView.backgroundColor = [UIColor grayColor];
  
  return cell;
}

- (void)setObject:(id<NSCopying>)object tappedHandler:(DFCollectionTableViewCellObjectTappedBlock)handler
{
  self.tapHandlers[object] = handler;
  self.collectionView.delegate = self;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  [collectionView deselectItemAtIndexPath:indexPath animated:NO];
  id tappedObject = self.objects[indexPath.row];
  DFCollectionTableViewCellObjectTappedBlock handler = self.tapHandlers[tappedObject];
  handler(tappedObject);
}

@end
