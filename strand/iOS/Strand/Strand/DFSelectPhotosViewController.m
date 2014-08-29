//
//  DFSelectPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectPhotosViewController.h"
#import "DFGallerySectionHeader.h"
#import "DFPhotoViewCell.h"
#import "DFPhotoStore.h"

@interface DFSelectPhotosViewController ()

@end

@implementation DFSelectPhotosViewController

- (instancetype)init
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    [self configureNavBar];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureCollectionView];
}

- (void)configureNavBar
{
  self.navigationItem.title = @"Select Photos";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                            target:self action:@selector(donePressed:)];
}

- (void)configureCollectionView
{
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  self.flowLayout.headerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionHeaderHeight);
  [self.collectionView registerNib:[UINib nibWithNibName:[DFPhotoViewCell description] bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
}

#pragma mark - UICollectionView Data/Delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    DFGallerySectionHeader *headerView = [self.collectionView
                                          dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                          withReuseIdentifier:@"headerView"
                                          forIndexPath:indexPath];
    headerView.titleLabel.text = self.sectionObject.title;
    headerView.subtitleLabel.text = self.sectionObject.subtitle;
    
    
    view = headerView;
  }
  return view;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return self.sectionObject.objects.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"cell"
                                                                         forIndexPath:indexPath];
  DFPeanutSearchObject *object = self.sectionObject.objects[indexPath.row];
  if ([object.type isEqual:DFSearchObjectCluster]) object = object.objects.firstObject;
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:object.id];
  
  cell.imageView.image = nil;
  [photo.asset loadUIImageForThumbnail:^(UIImage *image) {
    //if ([self.collectionView.visibleCells containsObject:cell]) {
    cell.imageView.image = image;
    [cell setNeedsLayout];
    //}
  } failureBlock:^(NSError *error) {
    DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
  }];
  
  return cell;
}



#pragma mark - Actions

- (void)donePressed:(id)sender
{
  
}



@end
