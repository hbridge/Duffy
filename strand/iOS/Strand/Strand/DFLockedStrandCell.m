//
//  DFLockedStrandCell.m
//  Strand
//
//  Created by Henry Bridge on 7/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFLockedStrandCell.h"
#import "DFPhotoViewCell.h"
#import <LiveFrost/LiveFrost.h>

@interface DFLockedStrandCell()

@property (atomic, retain) NSMutableDictionary *imagesForObjects;

@end

@implementation DFLockedStrandCell

- (void)awakeFromNib
{
  self.imagesForObjects = [NSMutableDictionary new];
  self.collectionView.delegate = self;
  self.collectionView.dataSource = self;
  self.collectionView.scrollsToTop = NO;
  self.collectionView.backgroundColor = [UIColor clearColor];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
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
  return self.imagesForObjects.allValues.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView
                           dequeueReusableCellWithReuseIdentifier:@"cell"
                           forIndexPath:indexPath];
  BOOL hasBlurView = NO;
  for (UIView *view in cell.subviews) {
    if ([view.class isSubclassOfClass:[LFGlassView class]]) {
      hasBlurView = YES;
      break;
    }
  }
  
  if (!hasBlurView) {
    LFGlassView *glassView = [[LFGlassView alloc] initWithFrame:cell.bounds];
    glassView.blurRadius = 1;
    [cell addSubview:glassView];
  }
  
  id object = self.objects[indexPath.row];
  cell.imageView.image = self.imagesForObjects[object];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  cell.imageView.backgroundColor = [UIColor grayColor];
  
  return cell;
}


@end
