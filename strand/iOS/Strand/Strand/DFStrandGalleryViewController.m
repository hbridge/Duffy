//
//  DFStrandGalleryViewController.m
//  Strand
//
//  Created by Henry Bridge on 9/26/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandGalleryViewController.h"
#import "DFPhotoViewCell.h"
#import "DFPeanutFeedObject.h"
#import "DFPhotoStackCell.h"
#import "DFPhoto.h"
#import "DFImageStore.h"
#import "DFSettingsViewController.h"
#import "DFGallerySectionHeader.h"
#import "DFFeedViewController.h"
#import "RootViewController.h"
#import "DFAnalytics.h"
#import "DFGalleryCollectionViewFlowLayout.h"
#import "NSString+DFHelpers.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"

static const CGFloat StrandGalleryItemSize = 105;
static const CGFloat StrandGalleryItemSpacing = 2.5;

@interface DFStrandGalleryViewController ()

@end

@implementation DFStrandGalleryViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.hidesBottomBarWhenPushed = YES;
  [self configureCollectionView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initNavigationAndTab
{
  self.navigationItem.title = self.strandPosts.title;
}

- (void)configureCollectionView
{
   self.collectionView.scrollsToTop = YES;
  
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"photoCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoStackCell" bundle:nil]
        forCellWithReuseIdentifier:@"clusterCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionFooter" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
               withReuseIdentifier:@"footerView"];
  
  
  self.collectionView.backgroundColor = [UIColor whiteColor];
  self.flowLayout.headerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionHeaderHeight);
  self.flowLayout.footerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionFooterHeight);
  self.flowLayout.itemSize = CGSizeMake(StrandGalleryItemSize, StrandGalleryItemSize);
  self.flowLayout.minimumInteritemSpacing = StrandGalleryItemSpacing;
  self.flowLayout.minimumLineSpacing = StrandGalleryItemSpacing;
  
  
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self action:@selector(reloadFeed)
                forControlEvents:UIControlEventValueChanged];
  [self.collectionView addSubview:self.refreshControl];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)strandsViewControllerUpdatedData:(DFStrandsViewController *)strandsViewController
{
  [self.collectionView reloadData];
}

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController didFinishServerFetchWithError:error
{
  [self.refreshControl endRefreshing];
}



# pragma mark - Collection View Datasource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return self.strandPosts.objects.count;
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    DFGallerySectionHeader *headerView = [self.collectionView
                                          dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                          withReuseIdentifier:@"headerView"
                                          forIndexPath:indexPath];
    
    DFPeanutFeedObject *postObject = [self postObjectForSection:indexPath.section];
    headerView.titleLabel.text = postObject.title;
    headerView.timeLabel.text = [NSDateFormatter relativeTimeStringSinceDate:postObject.time_taken
                                                                  abbreviate:YES];
    headerView.profilePhotoStackView.names = postObject.actorNames;
    
    
    view = headerView;
  } else if (kind == UICollectionElementKindSectionFooter) {
    view = [self.collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                   withReuseIdentifier:@"footerView"
                                                          forIndexPath:indexPath];
  }
  
  return view;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  DFPeanutFeedObject *postObject = [self postObjectForSection:section];
  
  NSArray *items = postObject.objects;
  return items.count;
}

- (DFPeanutFeedObject *)postObjectForSection:(NSUInteger)tableSection
{
  return self.strandPosts.objects[tableSection];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *cell;
  
  DFPeanutFeedObject *postObject = [self postObjectForSection:indexPath.section];
  NSArray *itemsForPost = postObject.objects;
  DFPeanutFeedObject *object = itemsForPost[indexPath.row];
  
  if ([object.type isEqual:DFFeedObjectPhoto]) {
    cell = [self cellForPhoto:object indexPath:indexPath];
  } else if ([object.type isEqual:DFFeedObjectCluster]) {
    cell = [self cellForCluster:object indexPath:indexPath];
  } else {
    // we don't know what type this is, show an unknown cell on Dev and make a best effort on prod
    cell = [self cellForUnknownObject:postObject atIndexPath:indexPath];
  }
  
  [cell setNeedsLayout];
  return cell;
}

- (UICollectionViewCell *)cellForUnknownObject:(DFPeanutFeedObject *)object atIndexPath:(NSIndexPath *)indexPath
{
#ifdef DEBUG
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell"
                                                                         forIndexPath:indexPath];
  cell.imageView.image = nil;
  cell.backgroundColor = [UIColor yellowColor];
#else
  //assume it's a regular photo
  UICollectionViewCell *cell = [self cellForPhoto:object indexPath:indexPath];
#endif
  return cell;
}

- (UICollectionViewCell *)cellForPhoto:(DFPeanutFeedObject *)photoObject
                             indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell" forIndexPath:indexPath];
  cell.imageView.image = nil;
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  
  NSArray *likeActions = [photoObject actionsOfType:DFPeanutActionFavorite forUser:0];
  cell.likeIconImageView.hidden = (likeActions.count <= 0);
  DFImageType preferredType = DFImageThumbnail;
  
  [[DFImageStore sharedStore]
   imageForID:photoObject.id
   preferredType:preferredType
   thumbnailPath:photoObject.thumb_image_path
   fullPath:photoObject.full_image_path
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       if
         (image) cell.imageView.image = image;
       else
         cell.imageView.image = [UIImage imageNamed:@"Assets/Icons/MissingImage320"];
       [cell setNeedsLayout];
     });
   }];
  
  return cell;
}

- (UICollectionViewCell *)cellForCluster:(DFPeanutFeedObject *)clusterObject
                               indexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"photoCell"
                                                                         forIndexPath:indexPath];
  cell.imageView.image = nil;
  cell.likeIconImageView.hidden = YES;
  for (DFPeanutFeedObject *object in clusterObject.objects) {
    if ([[object actionsOfType:DFPeanutActionFavorite forUser:0] count] > 0) {
      cell.likeIconImageView.hidden = NO;
      break;
    }
  }
  
  DFPeanutFeedObject *firstObject = (DFPeanutFeedObject *)clusterObject.objects.firstObject;
  
  [[DFImageStore sharedStore]
   imageForID:firstObject.id
   preferredType:DFImageThumbnail
   thumbnailPath:firstObject.thumb_image_path
   fullPath:firstObject.full_image_path
   completion:^(UIImage *image) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (![self.collectionView.visibleCells containsObject:cell]) return;
       cell.imageView.image = image;
       [cell setNeedsLayout];
     });
   }];
  
  return cell;
}

#pragma mark - Action Handlers

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoIDType photoID;
  DFPeanutFeedObject *postObject = [self postObjectForSection:indexPath.section];
  DFPeanutFeedObject *object = postObject.objects[indexPath.row];
  if ([object.type isEqualToString:DFFeedObjectPhoto]) {
    photoID = object.id;
  } else if ([object.type isEqualToString:DFFeedObjectCluster]) {
    photoID = ((DFPeanutFeedObject *)object.objects.firstObject).id;
  }
  
  DFFeedViewController *photoFeedController = [[DFFeedViewController alloc] init];
  photoFeedController.strandObjects = @[postObject];
  [self.navigationController pushViewController:photoFeedController animated:YES];
  dispatch_async(dispatch_get_main_queue(), ^{
    [photoFeedController showPhoto:photoID animated:NO];
  });
}

@end
