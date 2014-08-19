//
//  DFGalleryViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFGalleryViewController.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutSearchObject.h"
#import "DFPhotoStackCell.h"
#import "DFPhoto.h"
#import "DFImageStore.h"
#import "DFNavigationController.h"
#import "DFSettingsViewController.h"
#import "DFGallerySectionHeader.h"
#import "DFPhotoFeedController.h"
#import "RootViewController.h"


static const CGFloat ItemSize = 105;
static const CGFloat ItemSpacing = 2.5;
static const CGFloat SectionHeaderWidth = 320;
static const CGFloat SectionHeaderHeight = 54;


@interface DFGalleryViewController ()

@property (nonatomic, retain) UICollectionViewFlowLayout *flowLayout;

@end

@implementation DFGalleryViewController

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.delegate = self;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithImage:[UIImage imageNamed:@"Assets/Icons/SettingsBarButton"]
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(settingsButtonPressed:)];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.flowLayout = [[UICollectionViewFlowLayout alloc] init];
  self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame
                                           collectionViewLayout:self.flowLayout];

  [self.view addSubview:self.collectionView];
  [self configureCollectionView];
  
}

- (void)configureCollectionView
{
  self.collectionView.dataSource = self;
  self.collectionView.delegate = self;
  self.collectionView.scrollsToTop = YES;
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"photoCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoStackCell" bundle:nil]
        forCellWithReuseIdentifier:@"clusterCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  
  self.collectionView.backgroundColor = [UIColor whiteColor];
  self.flowLayout.headerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionHeaderHeight);
  self.flowLayout.itemSize = CGSizeMake(ItemSize, ItemSize);
  self.flowLayout.minimumInteritemSpacing = ItemSpacing;
  self.flowLayout.minimumLineSpacing = ItemSpacing;

}

- (void)strandsViewControllerUpdatedData:(DFStrandsViewController *)strandsViewController
{
[self.collectionView reloadData];
}

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController didFinishServerFetchWithError:error
{
  // Don't need to do anything for server refreshes
}



# pragma mark - Collection View Datasource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return self.sectionObjects.count + (self.uploadingPhotos.count > 0 ? 1 : 0);
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
  DFGallerySectionHeader *headerView = [self.collectionView
                                        dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                        withReuseIdentifier:@"headerView"
                                        forIndexPath:indexPath];
    if (self.uploadingPhotos.count > 0 && indexPath.section == 0) {
      headerView.titleLabel.text = @"Uploading Photos";
      headerView.subtitleLabel.text = @"These photos are currently uploading";
    } else {
      DFPeanutSearchObject *sectionObject = [self sectionObjectForUploadedSection:indexPath.section];
      headerView.titleLabel.text = sectionObject.title;
      headerView.subtitleLabel.text = sectionObject.subtitle;
    }
    
    view = headerView;
  }
  return view;
}




- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  if (self.uploadingPhotos.count > 0 && section == 0) {
    return self.uploadingPhotos.count;
  }
  
  DFPeanutSearchObject *sectionObject = [self sectionObjectForUploadedSection:section];
  
  if ([sectionObject isLockedSection]) {
    return 1;
  }
  
  NSArray *items = sectionObject.objects;
  return items.count;
}

- (DFPeanutSearchObject *)sectionObjectForUploadedSection:(NSUInteger)tableSection
{
  if (self.uploadingPhotos.count > 0) return self.sectionObjects[tableSection - 1];
  
  return self.sectionObjects[tableSection];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *cell;
  
  if (self.uploadingPhotos.count > 0 && indexPath.section == 0) {
    cell = [self cellForUploadAtIndexPath:indexPath];
  } else {
    DFPeanutSearchObject *section = [self sectionObjectForUploadedSection:indexPath.section];
    NSArray *itemsForSection = section.objects;
    DFPeanutSearchObject *object = itemsForSection[indexPath.row];
    
    if ([section isLockedSection]) {
      cell = [self cellForLockedSection:section indexPath:indexPath];
    } else if ([object.type isEqual:DFSearchObjectPhoto]) {
      cell = [self cellForPhoto:object indexPath:indexPath];
    } else if ([object.type isEqual:DFSearchObjectCluster]) {
      cell = [self cellForCluster:object indexPath:indexPath];
    }
  }
  
  [cell setNeedsLayout];
  return cell;
}

- (UICollectionViewCell *)cellForUploadAtIndexPath:(NSIndexPath *)indexPath
{
  //TODO complete
  
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  
  DFPhoto *firstPhoto = self.uploadingPhotos.firstObject;
  [firstPhoto.asset loadUIImageForThumbnail:^(UIImage *image) {
    if ([self.collectionView.visibleCells containsObject:cell]) {
      cell.imageView.image = image;
      [cell setNeedsLayout];
    }
  } failureBlock:^(NSError *error) {
    DDLogError(@"Error loading thumbnail for uploading asset.");
  }];
  
  return cell;
}

- (UICollectionViewCell *)cellForLockedSection:(DFPeanutSearchObject *)section
                                     indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *lockedCell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell"
                                                                               forIndexPath:indexPath];
  lockedCell.imageView.image = nil;

  //TODO complete
  DFPeanutSearchObject *object = section.objects.firstObject;
  [[DFImageStore sharedStore]
   imageForID:object.id
   preferredType:DFImageThumbnail
   thumbnailPath:object.thumb_image_path
   fullPath:object.full_image_path
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:lockedCell]) return;
       lockedCell.imageView.image = image;
       [lockedCell setNeedsLayout];
     });
   }];

  return lockedCell;
}

- (UICollectionViewCell *)cellForPhoto:(DFPeanutSearchObject *)photoObject
                             indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  
  [[DFImageStore sharedStore]
   imageForID:photoObject.id
   preferredType:DFImageThumbnail
   thumbnailPath:photoObject.thumb_image_path
   fullPath:photoObject.full_image_path
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       cell.imageView.image = image;
       [cell setNeedsLayout];
     });
   }];

  
  return cell;
}

- (UICollectionViewCell *)cellForCluster:(DFPeanutSearchObject *)clusterObject
                               indexPath:(NSIndexPath *)indexPath
{
  DFPhotoStackCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"clusterCell"
                                                                         forIndexPath:indexPath];
  cell.photoImageView.image = nil;
  
  DFPeanutSearchObject *firstObject = (DFPeanutSearchObject *)clusterObject.objects.firstObject;
  
  [[DFImageStore sharedStore]
   imageForID:firstObject.id
   preferredType:DFImageThumbnail
   thumbnailPath:firstObject.thumb_image_path
   fullPath:firstObject.full_image_path
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       cell.photoImageView.image = image;
       [cell setNeedsLayout];
     });
   }];

  return cell;
}

#pragma mark - Action Handlers

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (self.uploadingPhotos.count > 0 && indexPath.section == 0) {
    // don't do anything for uploading rows right now
  } else {
    DFPhotoIDType photoID;
    DFPeanutSearchObject *section = [self sectionObjectForUploadedSection:indexPath.section];
    DFPeanutSearchObject *object = section.objects[indexPath.row];
    if ([object.type isEqualToString:DFSearchObjectPhoto]) {
      photoID = object.id;
    } else if ([object.type isEqualToString:DFSearchObjectCluster]) {
      photoID = ((DFPeanutSearchObject *)object.objects.firstObject).id;
    }
    
    DFPhotoFeedController *photoFeedController =
    [(RootViewController *)self.view.window.rootViewController photoFeedController];
    [self.topBarController pushViewController:photoFeedController animated:YES];
    [photoFeedController jumpToPhoto:photoID];
  }
}



@end
